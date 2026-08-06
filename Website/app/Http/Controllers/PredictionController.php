<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

class PredictionController extends Controller
{
    public function predict(Request $request)
    {
        if (!$request->hasFile('image')) {

            return response()->json([
                "prediction" => "",
                "confidence" => "",
                "status" => "Error",
                "message" => "No image uploaded."
            ]);

        }

        $response = Http::attach(
            'file',
            file_get_contents($request->file('image')->getRealPath()),
            $request->file('image')->getClientOriginalName()
        )->post('http://127.0.0.1:5000/predict');

        if (!$response->successful()) {

            return response()->json([
                "prediction" => "",
                "confidence" => "",
                "status" => "Error",
                "message" => "Could not connect to AI Server."
            ]);

        }

        $data = $response->json();

        if (isset($data["error"])) {

            return response()->json([
                "prediction" => "",
                "confidence" => "",
                "status" => "Error",
                "message" => $data["error"],
                "probabilities" => (object) [],
                "heatmap" => null
            ]);

        }

        $prediction = $data["prediction"];

        // NOTE: These descriptions state the clinically-defined findings that
        // characterize each ICDR stage in general — they are NOT a claim that
        // the AI detected these specific lesions in this specific image. The
        // model is an image-level classifier; it was not trained to localize
        // or identify individual lesion types, so we never say "this image
        // shows X" — only "this stage is defined by X," which is factually
        // accurate regardless of what the model can or can't see.

        switch ($prediction) {

            case "No_DR":
                $explanation = "The AI classified this image as showing no apparent diabetic retinopathy. This stage is defined by the absence of microaneurysms, hemorrhages, or other visible vascular abnormalities on retinal examination. Regular eye examinations are still recommended, especially for patients with diabetes, since retinopathy can develop over time.";
                break;

            case "Mild":
                $explanation = "The AI classified this image as Mild Nonproliferative Diabetic Retinopathy (NPDR). This is the earliest visible stage of the disease, clinically defined by the presence of microaneurysms only — small, localized swellings in the retina's tiny blood vessels — without more advanced changes. Follow-up eye examinations are recommended to monitor progression.";
                break;

            case "Moderate":
                $explanation = "The AI classified this image as Moderate Nonproliferative Diabetic Retinopathy (NPDR). This stage is defined by more extensive vascular changes than Mild NPDR — including a greater number of microaneurysms and the presence of intraretinal hemorrhages and/or early signs of blocked blood vessels — but not yet meeting the criteria for Severe NPDR. Consultation with an eye specialist is advised.";
                break;

            case "Severe":
                $explanation = "The AI classified this image as Severe Nonproliferative Diabetic Retinopathy (NPDR). Clinically, this stage is defined by the '4-2-1 rule': more than 20 intraretinal hemorrhages in each of the four retinal quadrants, definite venous beading in two or more quadrants, or prominent intraretinal microvascular abnormalities (IRMA) in at least one quadrant — with no signs of proliferative disease yet. Prompt ophthalmologic evaluation is recommended.";
                break;

            case "Proliferate_DR":
                $explanation = "The AI classified this image as Proliferative Diabetic Retinopathy (PDR), the most advanced stage. This stage is clinically defined by neovascularization — the growth of new, abnormal, and fragile blood vessels on the retina — and/or vitreous or preretinal hemorrhage. This requires urgent evaluation by an ophthalmologist.";
                break;

            default:
                $explanation = "The AI completed the analysis successfully.";
                break;
        }

        return response()->json([
            "prediction" => $data["prediction"],
            "confidence" => $data["confidence"] . "%",
            "status" => "Success",
            "message" => $explanation,
            "probabilities" => $data["probabilities"],
            "heatmap" => $data["heatmap"],
            "quality_note" => $data["quality_note"] ?? null
        ]);
    }
}