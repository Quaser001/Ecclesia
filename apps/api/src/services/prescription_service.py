"""
Turn transcribed prescription text into profile suggestions.

Deterministic code only (AGENTS.md §2): the LLM transcribes, this module
decides. The tables below are a convenience for *suggestions the user must
confirm*, not a diagnostic tool. Text that matches nothing here can never add
a condition, which also means text printed on the page cannot talk its way in.
"""

from __future__ import annotations

import re

from src.domain.models import HealthCondition as HC
from src.domain.models import UserProfile
from src.domain.prescription import (
    AllergyKind,
    AllergySuggestion,
    ConditionSuggestion,
    PrescriptionObservation,
    PrescriptionSuggestions,
)

# Terms are matched case-insensitively as whole words/phrases.
_DIAGNOSIS_TERMS: dict[HC, tuple[str, ...]] = {
    HC.DIABETES_TYPE_1: ("type 1 diabetes", "type i diabetes", "t1dm", "iddm"),
    HC.DIABETES_TYPE_2: (
        "type 2 diabetes", "type ii diabetes", "diabetes mellitus type 2", "t2dm", "niddm",
    ),
    HC.PREDIABETES: ("prediabetes", "pre-diabetes", "impaired glucose tolerance"),
    HC.HYPERTENSION: ("hypertension", "high blood pressure", "htn"),
    HC.HIGH_CHOLESTEROL: (
        "high cholesterol", "hypercholesterolemia", "hypercholesterolaemia",
        "dyslipidemia", "dyslipidaemia",
    ),
    HC.CELIAC_DISEASE: ("celiac disease", "coeliac disease"),
    HC.IBS: ("irritable bowel syndrome", "ibs"),
    HC.KIDNEY_DISEASE: ("chronic kidney disease", "ckd", "kidney disease"),
    HC.HEART_DISEASE: ("coronary artery disease", "cad", "heart disease", "heart failure"),
    HC.OBESITY: ("obesity",),
    HC.LACTOSE_INTOLERANCE: ("lactose intolerance",),
    HC.ANAEMIA: ("anaemia", "anemia", "iron deficiency"),
}

# Medicines commonly prescribed for a condition. Weaker evidence than a stated
# diagnosis (e.g. metformin is also used for PCOS), so these are always marked
# "inferred_from_medicine" and the user decides.
_MEDICINE_TERMS: dict[HC, tuple[str, ...]] = {
    HC.DIABETES_TYPE_2: (
        "metformin", "glimepiride", "gliclazide", "sitagliptin", "vildagliptin",
    ),
    HC.HYPERTENSION: ("amlodipine", "telmisartan", "losartan", "olmesartan", "ramipril"),
    HC.HIGH_CHOLESTEROL: ("atorvastatin", "rosuvastatin", "simvastatin"),
    HC.ANAEMIA: ("ferrous", "ferrous sulfate", "ferrous sulphate"),
}

# "No allergies" written in the allergy field must never become an allergy.
_NO_ALLERGY_TOKENS = {"nkda", "nka", "nkfa", "nil", "nill", "none", "na", "n", "a", "no", "not"}
_NO_ALLERGY_LEAD = {"no", "nil", "none", "not"}

# Allergens that are not foods. The model's food/drug label is advisory; this
# list is the rule, so an allergen mislabelled "food" or "other" still is not
# offered as a profile allergy (profile allergies are matched against food).
_NON_FOOD_ALLERGENS = {
    "penicillin", "amoxicillin", "ampicillin", "cephalosporin", "cephalosporins",
    "sulfa", "sulpha", "sulfonamide", "sulfonamides", "sulphonamide", "aspirin",
    "nsaid", "nsaids", "ibuprofen", "diclofenac", "paracetamol", "tetracycline",
    "erythromycin", "azithromycin", "ciprofloxacin", "codeine", "morphine",
    "latex", "iodine", "contrast", "adhesive", "dust", "pollen",
}

# A diagnosis phrase that is negated, uncertain, family or past history is not a
# current condition. These go to "read but not added", never to suggestions.
# "k/c/o" (known case of) is deliberately NOT here: it states a current diagnosis.
_NON_CURRENT = re.compile(
    r"(?<![a-z0-9])(?:no|not|without|nil|denies|negative for|r/o|rule[d]? out|"
    r"f/h|fh|family history|history of|h/o)(?![a-z0-9])|\?",
    re.IGNORECASE,
)

# Same words, different disease (e.g. pulmonary hypertension is not systemic).
_DIAGNOSIS_EXCLUDE: dict[HC, re.Pattern[str]] = {
    HC.HYPERTENSION: re.compile(
        r"(?<![a-z0-9])(?:pulmonary|ocular|portal|intracranial|intraocular)"
        r"(?:\s+arterial)?\s+hypertension",
        re.IGNORECASE,
    ),
}

_NOT_A_PRESCRIPTION = (
    "This doesn't look like a prescription. "
    "Try a clear, well-lit photo of the whole page."
)
_NOTHING_FOUND = "We couldn't find anything to add from this photo."


def _compile(terms: tuple[str, ...]) -> re.Pattern[str]:
    alternatives = "|".join(re.escape(t) for t in sorted(terms, key=len, reverse=True))
    return re.compile(rf"(?<![a-z0-9])(?:{alternatives})(?![a-z0-9])", re.IGNORECASE)


_DIAGNOSIS_RE = {c: _compile(t) for c, t in _DIAGNOSIS_TERMS.items()}
_MEDICINE_RE = {c: _compile(t) for c, t in _MEDICINE_TERMS.items()}


def _norm_allergy(name: str) -> str:
    return re.sub(r"[^a-z0-9 ]+", " ", name.lower()).strip()


def _match(patterns: dict[HC, re.Pattern[str]], text: str) -> list[HC]:
    return [
        c
        for c, rx in patterns.items()
        if rx.search(text) and not (c in _DIAGNOSIS_EXCLUDE and _DIAGNOSIS_EXCLUDE[c].search(text))
    ]


def _is_no_allergy(key: str) -> bool:
    tokens = key.split()
    if not tokens:
        return True
    if all(t in _NO_ALLERGY_TOKENS for t in tokens):
        return True
    # "N.K.D.A." normalises to "n k d a"; also "NKDA NKFA".
    if re.fullmatch(r"(?:nk[dfa]?a)+", key.replace(" ", "")):
        return True
    # "no known food allergies", "none known", "nil known", "not known"
    return tokens[0] in _NO_ALLERGY_LEAD and any(
        t == "known" or t.startswith("allerg") for t in tokens
    )


def suggest_from_prescription(
    obs: PrescriptionObservation, profile: UserProfile
) -> PrescriptionSuggestions:
    """Pure function: no I/O, no model calls."""
    if not obs.is_prescription:
        return PrescriptionSuggestions(insufficient_data=True, message=_NOT_A_PRESCRIPTION)

    have_conditions = set(profile.health_conditions)
    have_allergies = {_norm_allergy(a) for a in profile.allergies}

    found: dict[HC, ConditionSuggestion] = {}
    unrecognised: list[str] = []

    for text in obs.diagnoses:
        if _NON_CURRENT.search(text):
            unrecognised.append(text)
            continue
        matches = _match(_DIAGNOSIS_RE, text)
        if not matches:
            unrecognised.append(text)
        for cond in matches:
            found[cond] = ConditionSuggestion(condition=cond, basis="stated", source_text=text)

    for text in obs.medicines:
        matches = _match(_MEDICINE_RE, text)
        if not matches:
            unrecognised.append(text)
        for cond in matches:
            # A stated diagnosis is stronger evidence; never downgrade it.
            found.setdefault(
                cond,
                ConditionSuggestion(
                    condition=cond, basis="inferred_from_medicine", source_text=text
                ),
            )

    conditions = [s for c, s in found.items() if c not in have_conditions]

    allergies: list[AllergySuggestion] = []
    seen = set(have_allergies)
    for allergy in obs.allergies:
        key = _norm_allergy(allergy.name)
        if _is_no_allergy(key):
            continue
        # Offer only things the model labelled as food AND that are not a known
        # drug/non-food allergen. Everything else is shown as "read, not added".
        if allergy.kind != AllergyKind.FOOD or set(key.split()) & _NON_FOOD_ALLERGENS:
            unrecognised.append(allergy.name)
            continue
        if key in seen:
            continue
        seen.add(key)
        allergies.append(AllergySuggestion(name=key, source_text=allergy.name))

    nothing = not conditions and not allergies
    return PrescriptionSuggestions(
        conditions=conditions,
        allergies=allergies,
        unrecognised=unrecognised,
        message=_NOTHING_FOUND if nothing else None,
    )
