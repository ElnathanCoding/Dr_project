package com.example.dr_package_app;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

import org.opencv.android.OpenCVLoader;
import org.opencv.core.Core;
import org.opencv.core.CvType;
import org.opencv.core.Mat;
import org.opencv.core.MatOfByte;
import org.opencv.core.Point;
import org.opencv.core.Rect;
import org.opencv.core.Scalar;
import org.opencv.core.Size;
import org.opencv.imgcodecs.Imgcodecs;
import org.opencv.imgproc.Imgproc;

import org.tensorflow.lite.Interpreter;
import org.tensorflow.lite.Tensor;

public final class MainActivity extends FlutterActivity {
    private static final String TAG = "IRIS_APP_NATIVE";
    private static final String CHANNEL = "iris.app/native_pipeline";

    private static final String GATE1 = "GATE1";
    private static final String MASTER11 = "MASTER11";
    private static final String GATE2 = "GATE2";
    private static final String MASTER12 = "MASTER12";
    private static final String E03 = "E03";

    private static final double GATE1_ACCEPT = 0.5001319401850001;

    private static final double MASTER11_LOWER = -0.00009904295646047104;
    private static final double MASTER11_ACCEPT = 0.00010095704353952897;

    private static final double GATE2_LOWER = 0.7847430871963501;
    private static final double GATE2_ACCEPT = 0.7849430871963501;

    private static final double MASTER12_ACCEPT = 0.475;

    private static final int UPSTREAM_SIZE = 224;
    private static final int P0_OUTPUT_SIZE = 512;
    private static final int P0_BACKGROUND_THRESHOLD = 7;
    private static final double P0_FOV_MARGIN_FRACTION = 0.02;

    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final Map<String, ModelRuntime> models = new LinkedHashMap<>();
    private volatile boolean openCvReady = false;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        openCvReady = OpenCVLoader.initLocal();
        Log.i(TAG, "OpenCV ready=" + openCvReady + " version=" + (openCvReady ? Core.VERSION : "NONE"));

        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                CHANNEL
        ).setMethodCallHandler((call, result) -> {
            if ("initModel".equals(call.method)) {
                Map<?, ?> args = (Map<?, ?>) call.arguments;
                if (args == null || !(args.get("name") instanceof String) || !(args.get("bytes") instanceof byte[])) {
                    result.error("INIT_ARGS", "Missing model name/bytes.", null);
                    return;
                }
                String name = (String) args.get("name");
                byte[] bytes = (byte[]) args.get("bytes");
                executor.execute(() -> {
                    try {
                        Map<String, Object> metadata = initializeModel(name, bytes);
                        mainHandler.post(() -> result.success(metadata));
                    } catch (Throwable t) {
                        Log.e(TAG, "Model init failed: " + name, t);
                        mainHandler.post(() -> result.error("INIT_FAILED", name + ": " + t, Log.getStackTraceString(t)));
                    }
                });
                return;
            }

            if ("runtimeInfo".equals(call.method)) {
                result.success(runtimeInfo());
                return;
            }

            if ("analyze".equals(call.method)) {
                if (!(call.arguments instanceof byte[])) {
                    result.error("ANALYZE_BYTES", "Encoded image bytes missing.", null);
                    return;
                }
                byte[] encoded = (byte[]) call.arguments;
                executor.execute(() -> {
                    try {
                        Map<String, Object> output = analyzeImage(encoded);
                        mainHandler.post(() -> result.success(output));
                    } catch (Throwable t) {
                        Log.e(TAG, "Pipeline failed", t);
                        mainHandler.post(() -> result.error("PIPELINE_FAILED", t.toString(), Log.getStackTraceString(t)));
                    }
                });
                return;
            }

            if ("dispose".equals(call.method)) {
                executor.execute(() -> {
                    closeModels();
                    mainHandler.post(() -> result.success(true));
                });
                return;
            }

            result.notImplemented();
        });
    }

    private static final class ModelRuntime {
        final String name;
        final ByteBuffer modelBuffer;
        final Interpreter interpreter;
        final ByteBuffer inputBuffer;
        final ByteBuffer outputBuffer;
        final int inputFloatCount;
        final int outputFloatCount;

        ModelRuntime(String name, ByteBuffer modelBuffer, Interpreter interpreter, int inputFloatCount, int outputFloatCount) {
            this.name = name;
            this.modelBuffer = modelBuffer;
            this.interpreter = interpreter;
            this.inputFloatCount = inputFloatCount;
            this.outputFloatCount = outputFloatCount;
            this.inputBuffer = ByteBuffer.allocateDirect(inputFloatCount * 4).order(ByteOrder.nativeOrder());
            this.outputBuffer = ByteBuffer.allocateDirect(outputFloatCount * 4).order(ByteOrder.nativeOrder());
        }

        float[] run(float[] input) {
            if (input.length != inputFloatCount) {
                throw new IllegalArgumentException(name + " expected " + inputFloatCount + " floats, got " + input.length);
            }
            inputBuffer.clear();
            inputBuffer.asFloatBuffer().put(input);
            inputBuffer.rewind();
            outputBuffer.clear();
            interpreter.run(inputBuffer, outputBuffer);
            outputBuffer.rewind();
            float[] output = new float[outputFloatCount];
            outputBuffer.asFloatBuffer().get(output);
            for (float value : output) {
                if (!Float.isFinite(value)) throw new IllegalStateException(name + " produced non-finite output.");
            }
            return output;
        }

        void close() {
            try { interpreter.close(); } catch (Throwable ignored) {}
        }
    }

    private Map<String, Object> initializeModel(String name, byte[] modelBytes) {
        if (models.containsKey(name)) return modelMetadata(models.get(name));

        final int expectedInputSize;
        final int expectedOutputCount;
        if (GATE1.equals(name) || MASTER11.equals(name) || GATE2.equals(name) || MASTER12.equals(name)) {
            expectedInputSize = 224;
            expectedOutputCount = 1;
        } else if (E03.equals(name)) {
            expectedInputSize = 512;
            expectedOutputCount = 5;
        } else {
            throw new IllegalArgumentException("Unknown model name: " + name);
        }

        ByteBuffer directModel = ByteBuffer.allocateDirect(modelBytes.length).order(ByteOrder.nativeOrder());
        directModel.put(modelBytes);
        directModel.rewind();

        Interpreter.Options options = new Interpreter.Options();
        options.setNumThreads(4);
        Interpreter interpreter = new Interpreter(directModel, options);

        Tensor inputTensor = interpreter.getInputTensor(0);
        Tensor outputTensor = interpreter.getOutputTensor(0);
        requireShape(inputTensor.shape(), new int[]{1, expectedInputSize, expectedInputSize, 3}, name + " input");
        requireShape(outputTensor.shape(), new int[]{1, expectedOutputCount}, name + " output");
        if (!"FLOAT32".equals(inputTensor.dataType().toString())) {
            interpreter.close();
            throw new IllegalStateException(name + " input dtype changed: " + inputTensor.dataType());
        }
        if (!"FLOAT32".equals(outputTensor.dataType().toString())) {
            interpreter.close();
            throw new IllegalStateException(name + " output dtype changed: " + outputTensor.dataType());
        }

        int inputCount = expectedInputSize * expectedInputSize * 3;
        ModelRuntime runtime = new ModelRuntime(name, directModel, interpreter, inputCount, expectedOutputCount);
        models.put(name, runtime);
        Map<String, Object> metadata = modelMetadata(runtime);
        Log.i(TAG, "IRIS_APP_NATIVE_INIT=" + metadata);
        return metadata;
    }

    private static void requireShape(int[] actual, int[] expected, String label) {
        if (actual.length != expected.length) throw new IllegalStateException(label + " rank mismatch.");
        for (int i = 0; i < actual.length; i++) {
            if (actual[i] != expected[i]) throw new IllegalStateException(label + " shape mismatch.");
        }
    }

    private Map<String, Object> modelMetadata(ModelRuntime model) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("name", model.name);
        map.put("input_shape", model.interpreter.getInputTensor(0).shape());
        map.put("output_shape", model.interpreter.getOutputTensor(0).shape());
        map.put("input_type", model.interpreter.getInputTensor(0).dataType().toString());
        map.put("output_type", model.interpreter.getOutputTensor(0).dataType().toString());
        return map;
    }

    private Map<String, Object> runtimeInfo() {
        Map<String, Object> info = new LinkedHashMap<>();
        info.put("opencv_ready", openCvReady);
        info.put("opencv_version", openCvReady ? Core.VERSION : "NOT_INITIALIZED");
        info.put("tensorflow_lite_runtime", "2.16.1");
        info.put("select_tf_ops", true);
        info.put("threads", 1);
        info.put("models_loaded", new ArrayList<>(models.keySet()));
        info.put("models_loaded_n", models.size());
        return info;
    }

    private Map<String, Object> analyzeImage(byte[] encodedBytes) {
        requireAllModels();
        if (!openCvReady) throw new IllegalStateException("OpenCV is not initialized.");
        if (encodedBytes == null || encodedBytes.length == 0) throw new IllegalArgumentException("Empty encoded image.");

        long startNs = System.nanoTime();

        long decodeStartNs = System.nanoTime();
        MatOfByte encoded = new MatOfByte(encodedBytes);
        Mat image = Imgcodecs.imdecode(encoded, Imgcodecs.IMREAD_COLOR);
        double decodeMs = elapsedMs(decodeStartNs);

        try {
            if (image.empty()) throw new IllegalStateException("Image decode failed.");
            if (image.type() != CvType.CV_8UC3) throw new IllegalStateException("Expected CV_8UC3 image.");

            Map<String, Object> result = new LinkedHashMap<>();
            result.put("original_width", image.cols());
            result.put("original_height", image.rows());
            result.put("decode_ms", decodeMs);

            long resize224StartNs = System.nanoTime();
            float[] upstream224 = resizeTensorFlowBilinearRgb(image, UPSTREAM_SIZE, UPSTREAM_SIZE);
            result.put("resize224_ms", elapsedMs(resize224StartNs));

            long gate1StartNs = System.nanoTime();
            double gate1Score = runScalar(GATE1, upstream224);
            result.put("gate1_ms", elapsedMs(gate1StartNs));
            result.put("gate1_score", gate1Score);
            if (gate1Score < GATE1_ACCEPT) {
                return stop(result, "GATE1", "STOP_NON_FUNDUS", "Not recognized as a supported retinal fundus photograph.", startNs);
            }

            long master11StartNs = System.nanoTime();
            double master11Score = runScalar(MASTER11, upstream224);
            result.put("master11_ms", elapsedMs(master11StartNs));
            result.put("master11_score", master11Score);
            if (master11Score < MASTER11_ACCEPT) {
                if (master11Score >= MASTER11_LOWER) {
                    return stop(result, "MASTER11", "STOP_MODALITY_BORDERLINE", "Retinal modality is numerically borderline. Use a supported standard color fundus photograph.", startNs);
                }
                return stop(result, "MASTER11", "STOP_UNSUPPORTED_MODALITY", "Unsupported retinal imaging modality.", startNs);
            }

            long gate2StartNs = System.nanoTime();
            double gate2Score = runScalar(GATE2, upstream224);
            result.put("gate2_ms", elapsedMs(gate2StartNs));
            result.put("gate2_score", gate2Score);
            if (gate2Score < GATE2_ACCEPT) {
                runShadowE03(image, result, "GATE2");
                if (gate2Score >= GATE2_LOWER) {
                    return stop(result, "GATE2", "STOP_QUALITY_BORDERLINE", "Image quality is borderline. Recapture or select a clearer fundus image.", startNs);
                }
                return stop(result, "GATE2", "STOP_UNGRADABLE", "Image quality is insufficient for safe DR staging.", startNs);
            }

            long master12StartNs = System.nanoTime();
            double master12Score = runScalar(MASTER12, upstream224);
            result.put("master12_ms", elapsedMs(master12StartNs));
            result.put("master12_score", master12Score);
            if (master12Score < MASTER12_ACCEPT) {
                runShadowE03(image, result, "MASTER12");
                return stop(result, "MASTER12", "STOP_OUT_OF_SCOPE", "Findings may be outside the supported DR-only scope. No DR stage will be issued.", startNs);
            }

            long p0StartNs = System.nanoTime();
            P0Result p0 = preprocessP0(image);
            result.put("p0_ms", elapsedMs(p0StartNs));
            result.put("p0_fallback", p0.fallback);
            result.put("p0_interpolation", p0.interpolation);
            result.put("p0_crop_x1", p0.x1);
            result.put("p0_crop_y1", p0.y1);
            result.put("p0_crop_x2", p0.x2);
            result.put("p0_crop_y2", p0.y2);

            long e03StartNs = System.nanoTime();
            float[] probabilities = models.get(E03).run(p0.tensor);
            result.put("e03_ms", elapsedMs(e03StartNs));

            double probabilitySum = 0.0;
            int highestIndex = 0;
            List<Double> probabilityList = new ArrayList<>();
            for (int i = 0; i < probabilities.length; i++) {
                probabilitySum += probabilities[i];
                probabilityList.add((double) probabilities[i]);
                if (probabilities[i] > probabilities[highestIndex]) highestIndex = i;
            }
            if (Math.abs(probabilitySum - 1.0) > 0.001) {
                throw new IllegalStateException("E03 probability sum failed: " + probabilitySum);
            }

            result.put("e03_probabilities", probabilityList);
            result.put("e03_index", highestIndex);
            result.put("e03_probability_sum", probabilitySum);
            result.put("final_stage", "E03");
            result.put("final_action", "E03_RESULT");
            result.put("message", "Image passed all four IRIS safety guards and reached E03.");
            result.put("total_ms", elapsedMs(startNs));

            Log.i(TAG, "IRIS_APP_TIMING=" + timingSummary(result));
            Log.i(TAG, "IRIS_APP_PIPELINE_RESULT=" + result);
            return result;
        } finally {
            encoded.release();
            image.release();
        }
    }

    // RETINA_SHADOW_E03_DIAGNOSTIC
    // Research-only deployment audit. The clinician-facing safety stop remains unchanged.
    private void runShadowE03(Mat image, Map<String, Object> result, String rejectedAt) {
        result.put("shadow_e03_rejected_at", rejectedAt);

        try {
            long p0StartNs = System.nanoTime();
            P0Result p0 = preprocessP0(image);
            result.put("shadow_p0_ms", elapsedMs(p0StartNs));

            long e03StartNs = System.nanoTime();
            float[] probabilities = models.get(E03).run(p0.tensor);
            result.put("shadow_e03_ms", elapsedMs(e03StartNs));

            double probabilitySum = 0.0;
            int highestIndex = 0;
            List<Double> probabilityList = new ArrayList<>();

            for (int i = 0; i < probabilities.length; i++) {
                probabilitySum += probabilities[i];
                probabilityList.add((double) probabilities[i]);
                if (probabilities[i] > probabilities[highestIndex]) highestIndex = i;
            }

            if (Math.abs(probabilitySum - 1.0) > 0.001) {
                throw new IllegalStateException(
                        "Shadow E03 probability sum failed: " + probabilitySum
                );
            }

            String[] labels = new String[]{
                    "No apparent DR",
                    "Mild NPDR",
                    "Moderate NPDR",
                    "Severe NPDR",
                    "Proliferative DR"
            };

            result.put("shadow_e03_probabilities", probabilityList);
            result.put("shadow_e03_index", highestIndex);
            result.put("shadow_e03_label", labels[highestIndex]);
            result.put("shadow_e03_probability_sum", probabilitySum);
            result.put("shadow_e03_research_only", true);
        } catch (Throwable shadowError) {
            result.put(
                    "shadow_e03_error",
                    shadowError.getClass().getSimpleName() + ": " + shadowError.getMessage()
            );
            Log.w(TAG, "RETINA_SHADOW_E03_ERROR", shadowError);
        }
    }
    private void requireAllModels() {
        String[] required = new String[]{GATE1, MASTER11, GATE2, MASTER12, E03};
        for (String name : required) {
            if (!models.containsKey(name)) throw new IllegalStateException("Model not loaded: " + name);
        }
    }

    private double runScalar(String modelName, float[] input) {
        ModelRuntime model = models.get(modelName);
        if (model == null) throw new IllegalStateException("Missing model: " + modelName);
        float[] output = model.run(input);
        if (output.length != 1) throw new IllegalStateException(modelName + " output length changed.");
        return output[0];
    }

    private Map<String, Object> stop(Map<String, Object> result, String stage, String action, String message, long startNs) {
        result.put("final_stage", stage);
        result.put("final_action", action);
        result.put("message", message);
        result.put("total_ms", elapsedMs(startNs));
        Log.i(TAG, "IRIS_APP_TIMING=" + timingSummary(result));
        Log.i(TAG, "IRIS_APP_PIPELINE_STOP=" + result);
        return result;
    }

    private static String timingSummary(Map<String, Object> result) {
        return "decode_ms=" + result.get("decode_ms")
                + ",resize224_ms=" + result.get("resize224_ms")
                + ",gate1_ms=" + result.get("gate1_ms")
                + ",master11_ms=" + result.get("master11_ms")
                + ",gate2_ms=" + result.get("gate2_ms")
                + ",master12_ms=" + result.get("master12_ms")
                + ",p0_ms=" + result.get("p0_ms")
                + ",e03_ms=" + result.get("e03_ms")
                + ",total_ms=" + result.get("total_ms");
    }

    private static double elapsedMs(long startNs) {
        return (System.nanoTime() - startNs) / 1_000_000.0;
    }

    // Matches tf.image.resize(..., method='bilinear', antialias=False) coordinate convention.
    private static float[] resizeTensorFlowBilinearRgb(Mat bgr, int outWidth, int outHeight) {
        int inHeight = bgr.rows();
        int inWidth = bgr.cols();
        byte[] src = new byte[inHeight * inWidth * 3];
        int read = bgr.get(0, 0, src);
        if (read != src.length) throw new IllegalStateException("Could not extract decoded BGR pixels.");

        int[] x0 = new int[outWidth];
        int[] x1 = new int[outWidth];
        double[] wx = new double[outWidth];
        for (int x = 0; x < outWidth; x++) {
            double sourceX = ((x + 0.5) * inWidth / (double) outWidth) - 0.5;
            sourceX = Math.max(0.0, Math.min(sourceX, inWidth - 1.0));
            int left = (int) Math.floor(sourceX);
            int right = Math.min(left + 1, inWidth - 1);
            x0[x] = left;
            x1[x] = right;
            wx[x] = sourceX - left;
        }

        float[] output = new float[outHeight * outWidth * 3];
        int[] sourceChannels = new int[]{2, 1, 0};
        for (int y = 0; y < outHeight; y++) {
            double sourceY = ((y + 0.5) * inHeight / (double) outHeight) - 0.5;
            sourceY = Math.max(0.0, Math.min(sourceY, inHeight - 1.0));
            int top = (int) Math.floor(sourceY);
            int bottom = Math.min(top + 1, inHeight - 1);
            double wy = sourceY - top;
            for (int x = 0; x < outWidth; x++) {
                int left = x0[x];
                int right = x1[x];
                double weightX = wx[x];
                int outputBase = (y * outWidth + x) * 3;
                for (int outChannel = 0; outChannel < 3; outChannel++) {
                    int sourceChannel = sourceChannels[outChannel];
                    double p00 = unsignedByte(src, inWidth, top, left, sourceChannel);
                    double p01 = unsignedByte(src, inWidth, top, right, sourceChannel);
                    double p10 = unsignedByte(src, inWidth, bottom, left, sourceChannel);
                    double p11 = unsignedByte(src, inWidth, bottom, right, sourceChannel);
                    double topValue = p00 + (p01 - p00) * weightX;
                    double bottomValue = p10 + (p11 - p10) * weightX;
                    output[outputBase + outChannel] = (float) (topValue + (bottomValue - topValue) * wy);
                }
            }
        }
        return output;
    }

    private static int unsignedByte(byte[] data, int width, int y, int x, int channel) {
        return data[((y * width + x) * 3) + channel] & 0xff;
    }

    private static final class P0Result {
        final float[] tensor;
        final boolean fallback;
        final String interpolation;
        final int x1, y1, x2, y2;

        P0Result(float[] tensor, boolean fallback, String interpolation, int x1, int y1, int x2, int y2) {
            this.tensor = tensor;
            this.fallback = fallback;
            this.interpolation = interpolation;
            this.x1 = x1;
            this.y1 = y1;
            this.x2 = x2;
            this.y2 = y2;
        }
    }

    private static P0Result preprocessP0(Mat image) {
        Mat gray = new Mat();
        Mat mask = new Mat();
        Mat kernel = new Mat();
        Mat labels = new Mat();
        Mat stats = new Mat();
        Mat centroids = new Mat();
        Mat cropped = new Mat();
        Mat squared = new Mat();
        Mat resized = new Mat();
        Mat rgb = new Mat();

        try {
            int originalHeight = image.rows();
            int originalWidth = image.cols();

            Imgproc.cvtColor(image, gray, Imgproc.COLOR_BGR2GRAY);
            Imgproc.threshold(gray, mask, P0_BACKGROUND_THRESHOLD, 255.0, Imgproc.THRESH_BINARY);
            kernel = Imgproc.getStructuringElement(Imgproc.MORPH_ELLIPSE, new Size(5, 5));
            Imgproc.morphologyEx(mask, mask, Imgproc.MORPH_CLOSE, kernel, new Point(-1, -1), 2);

            int numberOfLabels = Imgproc.connectedComponentsWithStats(mask, labels, stats, centroids, 8, CvType.CV_32S);
            int x1, y1, x2, y2;
            boolean fallback = false;

            if (numberOfLabels <= 1) {
                x1 = 0; y1 = 0; x2 = originalWidth; y2 = originalHeight; fallback = true;
            } else {
                int largestLabel = 1;
                int largestArea = (int) stats.get(1, Imgproc.CC_STAT_AREA)[0];
                for (int label = 2; label < numberOfLabels; label++) {
                    int area = (int) stats.get(label, Imgproc.CC_STAT_AREA)[0];
                    if (area > largestArea) {
                        largestArea = area;
                        largestLabel = label;
                    }
                }

                int x = (int) stats.get(largestLabel, Imgproc.CC_STAT_LEFT)[0];
                int y = (int) stats.get(largestLabel, Imgproc.CC_STAT_TOP)[0];
                int boxWidth = (int) stats.get(largestLabel, Imgproc.CC_STAT_WIDTH)[0];
                int boxHeight = (int) stats.get(largestLabel, Imgproc.CC_STAT_HEIGHT)[0];
                long detectedArea = (long) boxWidth * boxHeight;
                long imageArea = (long) originalWidth * originalHeight;
                double bboxFraction = ((double) detectedArea) / Math.max(imageArea, 1L);

                if (bboxFraction < 0.20) {
                    x1 = 0; y1 = 0; x2 = originalWidth; y2 = originalHeight; fallback = true;
                } else {
                    int margin = (int) Math.rint(Math.max(boxWidth, boxHeight) * P0_FOV_MARGIN_FRACTION);
                    x1 = Math.max(0, x - margin);
                    y1 = Math.max(0, y - margin);
                    x2 = Math.min(originalWidth, x + boxWidth + margin);
                    y2 = Math.min(originalHeight, y + boxHeight + margin);
                }
            }

            if (x2 <= x1 || y2 <= y1) {
                cropped.release();
                cropped = image.clone();
                x1 = 0; y1 = 0; x2 = originalWidth; y2 = originalHeight; fallback = true;
            } else {
                Rect cropRect = new Rect(x1, y1, x2 - x1, y2 - y1);
                cropped.release();
                cropped = new Mat(image, cropRect).clone();
                if (cropped.empty()) {
                    cropped.release();
                    cropped = image.clone();
                    x1 = 0; y1 = 0; x2 = originalWidth; y2 = originalHeight; fallback = true;
                }
            }

            int cropHeight = cropped.rows();
            int cropWidth = cropped.cols();
            int side = Math.max(cropHeight, cropWidth);
            int padTop = (side - cropHeight) / 2;
            int padBottom = side - cropHeight - padTop;
            int padLeft = (side - cropWidth) / 2;
            int padRight = side - cropWidth - padLeft;

            Core.copyMakeBorder(cropped, squared, padTop, padBottom, padLeft, padRight, Core.BORDER_CONSTANT, new Scalar(0, 0, 0));

            int interpolation = (squared.cols() > P0_OUTPUT_SIZE || squared.rows() > P0_OUTPUT_SIZE)
                    ? Imgproc.INTER_AREA
                    : Imgproc.INTER_CUBIC;

            Imgproc.resize(squared, resized, new Size(P0_OUTPUT_SIZE, P0_OUTPUT_SIZE), 0.0, 0.0, interpolation);
            if (resized.rows() != P0_OUTPUT_SIZE || resized.cols() != P0_OUTPUT_SIZE || resized.type() != CvType.CV_8UC3) {
                throw new IllegalStateException("Unexpected P0 output.");
            }

            Imgproc.cvtColor(resized, rgb, Imgproc.COLOR_BGR2RGB);
            byte[] rgbBytes = new byte[P0_OUTPUT_SIZE * P0_OUTPUT_SIZE * 3];
            int rgbRead = rgb.get(0, 0, rgbBytes);
            if (rgbRead != rgbBytes.length) throw new IllegalStateException("Could not extract all P0 RGB pixels.");

            float[] tensor = new float[rgbBytes.length];
            for (int i = 0; i < rgbBytes.length; i++) tensor[i] = rgbBytes[i] & 0xff;
            String interpolationName = interpolation == Imgproc.INTER_AREA ? "INTER_AREA" : "INTER_CUBIC";
            return new P0Result(tensor, fallback, interpolationName, x1, y1, x2, y2);
        } finally {
            gray.release();
            mask.release();
            kernel.release();
            labels.release();
            stats.release();
            centroids.release();
            cropped.release();
            squared.release();
            resized.release();
            rgb.release();
        }
    }

    private void closeModels() {
        for (ModelRuntime model : models.values()) model.close();
        models.clear();
    }

    @Override
    protected void onDestroy() {
        try { closeModels(); } catch (Throwable ignored) {}
        executor.shutdownNow();
        super.onDestroy();
    }
}
