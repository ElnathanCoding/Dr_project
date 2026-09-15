RETINA APP VISUAL ASSET PACK

BRANDING
- retina_logo_final.png
  This is the exact logo image you chose.

READY_NOW
- retina_splash.png
- how_retina_works.png
- accepted_image_guide.png
- rejected_image_guide.png
- what_is_diabetic_retinopathy.png
- about_retina.png

NEEDS_TEXT_REVIEW BEFORE FINAL APP
- icdr_scale_draft.png
- how_ai_helps_draft.png
- understanding_results_draft.png
- why_this_result_draft.png

Why some are marked NEEDS_TEXT_REVIEW:
The visual style is good, but the wording needs a scientific pass before shipping.
Examples:
- raw E03 softmax outputs should not be described as guaranteed diagnostic probabilities;
- "No apparent DR" should not be labeled simply "normal";
- lesion illustrations must be clearly presented as general educational examples, not proof that RETINA detected those specific lesions;
- RETINA is a DR-only research prototype and does not diagnose other retinal diseases.

NEXT APP IMPLEMENTATION
Copy the final approved files into:
  dr_package_app/assets/images/

Then add the assets folder to pubspec.yaml and wire them into the Learn / IRIS / About tabs.
