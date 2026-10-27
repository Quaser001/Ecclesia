-- Migration 007 — optional body details on the profile.
--
-- All nullable: nothing is required and nothing is guessed. BMI is not
-- stored; the API calculates it from height and weight on every read.
-- Ranges mirror the API's Pydantic validation (src/domain/models.py).
alter table public.profiles
  add column if not exists height_cm        numeric(5,1) check (height_cm between 50 and 250),
  add column if not exists weight_kg        numeric(5,1) check (weight_kg between 15 and 350),
  add column if not exists target_weight_kg numeric(5,1) check (target_weight_kg between 15 and 350),
  add column if not exists birth_year       smallint     check (birth_year >= 1900),
  add column if not exists sex              text         check (sex in ('female', 'male', 'other')),
  add column if not exists activity_level   text         check (activity_level in
                                              ('sedentary', 'light', 'moderate', 'active', 'very_active'));
