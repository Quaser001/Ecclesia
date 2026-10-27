-- CalFit Development Seed Data — Migration 002
-- ⚠️  DEV DATA ONLY — clearly marked, not real product claims
-- This seed provides enough knowledge entries to test the complete workflow.
-- Run AFTER 001_schema.sql

-- ---------------------------------------------------------------------------
-- Dev test profile (used in automated tests)
-- ---------------------------------------------------------------------------
INSERT INTO profiles (user_id, name, health_conditions, allergies, dietary_preferences, health_goals)
VALUES
    ('dev-user-001', 'Dev User (Healthy)', '{}', '{}', '{}', '{"maintain_weight"}'),
    ('dev-user-diabetic', 'Dev User (Diabetic)', '{"diabetes_type_2"}', '{}', '{}', '{"manage_blood_sugar"}'),
    ('dev-user-hypertensive', 'Dev User (Hypertension)', '{"hypertension"}', '{}', '{}', '{"heart_health"}'),
    ('dev-user-allergic', 'Dev User (Nut Allergy)', '{}', '{"peanuts", "tree nuts"}', '{}', '{}'),
    ('dev-user-vegan', 'Dev User (Vegan)', '{}', '{}', '{"vegan"}', '{"maintain_weight"}')
ON CONFLICT (user_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Knowledge base entries
-- These cover ingredients, nutrients, and condition relevance.
-- Source: general nutritional science — not specific product claims.
-- ---------------------------------------------------------------------------
INSERT INTO knowledge (topic, content, relevance_tags, source) VALUES

-- Sodium / Hypertension
('sodium_hypertension',
 'High sodium intake is a significant risk factor for hypertension (high blood pressure). '
 'The American Heart Association recommends no more than 2300 mg of sodium per day for most adults, '
 'and ideally 1500 mg for those with hypertension. Processed and packaged foods are the primary '
 'source of sodium in modern diets.',
 '{"sodium", "hypertension", "heart_disease", "blood_pressure"}',
 'calfit_knowledge_base'),

-- Sugar / Diabetes
('sugar_diabetes',
 'Rapidly absorbed sugars (including sucrose, glucose, fructose, and corn syrup) cause sharp increases '
 'in blood glucose levels. For individuals with type 2 diabetes, limiting added sugar is critical for '
 'blood glucose management. Foods with high sugar content should be consumed in moderation or avoided.',
 '{"sugar", "diabetes_type_2", "diabetes_type_1", "blood_glucose", "glycaemic_index"}',
 'calfit_knowledge_base'),

-- High-fructose corn syrup
('high_fructose_corn_syrup',
 'High-fructose corn syrup (HFCS) is an added sweetener linked to insulin resistance, obesity, '
 'and elevated triglycerides. It is rapidly absorbed and provides no nutritional benefit. '
 'Often found in soft drinks, processed snacks, sauces, and packaged foods.',
 '{"sugar", "hfcs", "diabetes_type_2", "obesity", "weight_loss"}',
 'calfit_knowledge_base'),

-- Saturated fat / Cholesterol
('saturated_fat_cholesterol',
 'Saturated fat raises LDL ("bad") cholesterol, increasing the risk of cardiovascular disease. '
 'The WHO recommends limiting saturated fat to less than 10% of total energy intake. '
 'Common sources include meat, full-fat dairy, palm oil, and coconut oil.',
 '{"saturated_fat", "cholesterol", "heart_disease", "high_cholesterol", "cardiovascular"}',
 'calfit_knowledge_base'),

-- Trans fat
('trans_fat',
 'Artificial trans fats (partially hydrogenated oils) raise LDL cholesterol and lower HDL cholesterol, '
 'significantly increasing the risk of heart disease. Most countries have restrictions or bans on trans fats. '
 'Even small amounts should be avoided by those with high cholesterol or heart disease.',
 '{"trans_fat", "cholesterol", "heart_disease", "high_cholesterol"}',
 'calfit_knowledge_base'),

-- Gluten / Celiac
('gluten_celiac',
 'Gluten is a protein found in wheat, barley, rye, and related grains. For individuals with celiac disease, '
 'consuming gluten triggers an autoimmune response that damages the small intestine. '
 'Strict lifelong avoidance of gluten is required for celiac disease management.',
 '{"gluten", "wheat", "barley", "rye", "celiac_disease", "gluten_free"}',
 'calfit_knowledge_base'),

-- Dairy / Lactose intolerance
('dairy_lactose',
 'Lactose is the primary sugar in dairy products. Individuals with lactose intolerance lack sufficient '
 'lactase enzyme to digest lactose, leading to digestive symptoms. Dairy-derived ingredients include '
 'milk, cream, butter, whey, casein, lactose, and most cheeses.',
 '{"dairy", "milk", "lactose", "lactose_intolerance", "dairy_free"}',
 'calfit_knowledge_base'),

-- Peanuts / Allergy
('peanut_allergy',
 'Peanut allergy is one of the most common and potentially severe food allergies. '
 'Even trace amounts can trigger anaphylaxis in highly sensitive individuals. '
 'Peanuts and peanut-derived ingredients must be completely avoided. '
 'Cross-contamination is a significant risk in shared manufacturing facilities.',
 '{"peanuts", "nuts", "allergy", "allergen", "anaphylaxis"}',
 'calfit_knowledge_base'),

-- Tree nuts / Allergy
('tree_nut_allergy',
 'Tree nut allergy (cashews, walnuts, almonds, pistachios, etc.) can cause severe allergic reactions. '
 'It is distinct from peanut allergy (peanuts are legumes). Tree nut allergies often persist into adulthood. '
 'Individuals should avoid all tree nuts unless confirmed safe by their allergist.',
 '{"tree_nuts", "cashews", "walnuts", "almonds", "allergy", "allergen"}',
 'calfit_knowledge_base'),

-- Instant noodles category context
('instant_noodles_profile',
 'Instant noodles are typically high in sodium, refined carbohydrates, and saturated fat. '
 'A single serving often contains 800-1500 mg of sodium and 300-450 kcal. '
 'They typically contain MSG, flavour enhancers (E621), and palm oil. '
 'They are not recommended for daily consumption for individuals with hypertension or diabetes.',
 '{"instant_noodles", "processed_food", "sodium", "refined_carbs", "palm_oil"}',
 'calfit_knowledge_base'),

-- Fibre / Digestive health
('dietary_fibre',
 'Dietary fibre supports digestive health, helps regulate blood sugar levels, and reduces cholesterol. '
 'Most adults need 25-35 g of fibre per day. High-fibre foods include whole grains, legumes, vegetables, '
 'and fruits. Low fibre intake is associated with constipation and increased colorectal cancer risk.',
 '{"fibre", "digestive_health", "ibs", "diabetes_type_2", "cholesterol"}',
 'calfit_knowledge_base'),

-- Protein / Muscle gain
('protein_muscle',
 'Adequate protein intake is essential for muscle growth and repair. '
 'General guidance for muscle gain: 1.6-2.2 g of protein per kg of body weight per day. '
 'High-quality protein sources include lean meat, fish, eggs, dairy, legumes, and soy.',
 '{"protein", "muscle_gain", "fitness", "amino_acids"}',
 'calfit_knowledge_base');

-- ---------------------------------------------------------------------------
-- Dev alternatives (verified examples for testing alternative retrieval)
-- ⚠️  These are example entries, not specific product endorsements
-- ---------------------------------------------------------------------------
INSERT INTO alternatives (name, brand, category, reason, health_tags) VALUES
    ('Lower-Sodium Instant Noodles Example',
     null,
     'instant noodles',
     'DEV DATA: Example entry for an instant noodle with <600mg sodium per serving. '
     'In a real deployment, verified lower-sodium alternatives would be listed here.',
     '{"low_sodium", "hypertension"}'),
    ('Gluten-Free Pasta Example',
     null,
     'pasta',
     'DEV DATA: Example entry for a rice-based or lentil-based pasta alternative for gluten-free needs.',
     '{"gluten_free", "celiac"}');
