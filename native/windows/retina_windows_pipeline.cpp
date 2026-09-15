#define WIN32_LEAN_AND_MEAN
#define NOMINMAX

#include <windows.h>

#include <opencv2/opencv.hpp>

#include "tensorflow/lite/c/c_api.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <iomanip>
#include <map>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

namespace {

using Clock = std::chrono::steady_clock;

constexpr double GATE1_ACCEPT =
    0.5001319401850001;

constexpr double MASTER11_LOWER =
    -0.00009904295646047104;

constexpr double MASTER11_ACCEPT =
    0.00010095704353952897;

constexpr double GATE2_LOWER =
    0.7847430871963501;

constexpr double GATE2_ACCEPT =
    0.7849430871963501;

constexpr double MASTER12_ACCEPT =
    0.475;

constexpr int UPSTREAM_SIZE =
    224;

constexpr int P0_OUTPUT_SIZE =
    512;

constexpr int P0_BACKGROUND_THRESHOLD =
    7;

constexpr double P0_FOV_MARGIN_FRACTION =
    0.02;

const char* GATE1 =
    "GATE1";

const char* MASTER11 =
    "MASTER11";

const char* GATE2 =
    "GATE2";

const char* MASTER12 =
    "MASTER12";

const char* E03 =
    "E03";

std::string wideToUtf8(
    const std::wstring& input
) {
    if (input.empty()) {
        return {};
    }

    int required =
        WideCharToMultiByte(
            CP_UTF8,
            0,
            input.c_str(),
            static_cast<int>(input.size()),
            nullptr,
            0,
            nullptr,
            nullptr
        );

    if (required <= 0) {
        throw std::runtime_error(
            "WideCharToMultiByte failed."
        );
    }

    std::string output(
        required,
        '\0'
    );

    WideCharToMultiByte(
        CP_UTF8,
        0,
        input.c_str(),
        static_cast<int>(input.size()),
        output.data(),
        required,
        nullptr,
        nullptr
    );

    return output;
}

std::wstring joinPath(
    const std::wstring& directory,
    const std::wstring& file
) {
    if (directory.empty()) {
        return file;
    }

    wchar_t last =
        directory.back();

    if (
        last == L'\\' ||
        last == L'/'
    ) {
        return directory + file;
    }

    return directory + L"\\" + file;
}

double elapsedMs(
    Clock::time_point start
) {
    return std::chrono::duration<
        double,
        std::milli
    >(
        Clock::now() - start
    ).count();
}

std::string jsonEscape(
    const std::string& input
) {
    std::ostringstream out;

    for (unsigned char c : input) {

        switch (c) {
            case '"':
                out << "\\\"";
                break;

            case '\\':
                out << "\\\\";
                break;

            case '\b':
                out << "\\b";
                break;

            case '\f':
                out << "\\f";
                break;

            case '\n':
                out << "\\n";
                break;

            case '\r':
                out << "\\r";
                break;

            case '\t':
                out << "\\t";
                break;

            default:
                if (c < 0x20) {
                    out
                        << "\\u"
                        << std::hex
                        << std::setw(4)
                        << std::setfill('0')
                        << static_cast<int>(c)
                        << std::dec;
                } else {
                    out << c;
                }

                break;
        }
    }

    return out.str();
}

std::string jsonString(
    const std::string& input
) {
    return "\"" +
        jsonEscape(input) +
        "\"";
}

std::string jsonNumber(
    double value
) {
    if (!std::isfinite(value)) {
        throw std::runtime_error(
            "Attempted to serialize non-finite number."
        );
    }

    std::ostringstream out;

    out <<
        std::setprecision(17) <<
        value;

    return out.str();
}

std::string jsonInt(
    long long value
) {
    return std::to_string(value);
}

std::string jsonBool(
    bool value
) {
    return value
        ? "true"
        : "false";
}

std::string jsonFloatArray(
    const std::vector<float>& values
) {
    std::ostringstream out;

    out << "[";

    for (
        size_t i = 0;
        i < values.size();
        ++i
    ) {
        if (i != 0) {
            out << ",";
        }

        out <<
            std::setprecision(9) <<
            values[i];
    }

    out << "]";

    return out.str();
}

class JsonObject {
public:
    void setRaw(
        const std::string& key,
        const std::string& value
    ) {
        for (auto& entry : entries_) {
            if (entry.first == key) {
                entry.second = value;
                return;
            }
        }

        entries_.emplace_back(
            key,
            value
        );
    }

    void setString(
        const std::string& key,
        const std::string& value
    ) {
        setRaw(
            key,
            jsonString(value)
        );
    }

    void setNumber(
        const std::string& key,
        double value
    ) {
        setRaw(
            key,
            jsonNumber(value)
        );
    }

    void setInt(
        const std::string& key,
        long long value
    ) {
        setRaw(
            key,
            jsonInt(value)
        );
    }

    void setBool(
        const std::string& key,
        bool value
    ) {
        setRaw(
            key,
            jsonBool(value)
        );
    }

    std::string str() const {
        std::ostringstream out;

        out << "{";

        for (
            size_t i = 0;
            i < entries_.size();
            ++i
        ) {
            if (i != 0) {
                out << ",";
            }

            out
                << jsonString(entries_[i].first)
                << ":"
                << entries_[i].second;
        }

        out << "}";

        return out.str();
    }

private:
    std::vector<
        std::pair<
            std::string,
            std::string
        >
    > entries_;
};

template <typename T>
T loadSymbol(
    HMODULE module,
    const char* name
) {
    FARPROC proc =
        GetProcAddress(
            module,
            name
        );

    if (proc == nullptr) {
        throw std::runtime_error(
            std::string("Missing symbol: ") +
            name
        );
    }

    return reinterpret_cast<T>(
        proc
    );
}

struct TfLiteApi {
    decltype(&TfLiteVersion)
        version = nullptr;

    decltype(&TfLiteModelCreateFromFile)
        modelCreateFromFile = nullptr;

    decltype(&TfLiteModelDelete)
        modelDelete = nullptr;

    decltype(&TfLiteInterpreterOptionsCreate)
        optionsCreate = nullptr;

    decltype(&TfLiteInterpreterOptionsDelete)
        optionsDelete = nullptr;

    decltype(&TfLiteInterpreterOptionsSetNumThreads)
        optionsSetThreads = nullptr;

    decltype(&TfLiteInterpreterOptionsAddDelegate)
        optionsAddDelegate = nullptr;

    decltype(&TfLiteInterpreterCreate)
        interpreterCreate = nullptr;

    decltype(&TfLiteInterpreterDelete)
        interpreterDelete = nullptr;

    decltype(&TfLiteInterpreterAllocateTensors)
        allocateTensors = nullptr;

    decltype(&TfLiteInterpreterInvoke)
        invoke = nullptr;

    decltype(&TfLiteInterpreterGetInputTensorCount)
        inputCount = nullptr;

    decltype(&TfLiteInterpreterGetOutputTensorCount)
        outputCount = nullptr;

    decltype(&TfLiteInterpreterGetInputTensor)
        getInput = nullptr;

    decltype(&TfLiteInterpreterGetOutputTensor)
        getOutput = nullptr;

    decltype(&TfLiteTensorType)
        tensorType = nullptr;

    decltype(&TfLiteTensorNumDims)
        tensorNumDims = nullptr;

    decltype(&TfLiteTensorDim)
        tensorDim = nullptr;

    decltype(&TfLiteTensorByteSize)
        tensorByteSize = nullptr;

    decltype(&TfLiteTensorCopyFromBuffer)
        copyFromBuffer = nullptr;

    decltype(&TfLiteTensorCopyToBuffer)
        copyToBuffer = nullptr;

    void load(
        HMODULE module
    ) {
        version =
            loadSymbol<
                decltype(version)
            >(
                module,
                "TfLiteVersion"
            );

        modelCreateFromFile =
            loadSymbol<
                decltype(modelCreateFromFile)
            >(
                module,
                "TfLiteModelCreateFromFile"
            );

        modelDelete =
            loadSymbol<
                decltype(modelDelete)
            >(
                module,
                "TfLiteModelDelete"
            );

        optionsCreate =
            loadSymbol<
                decltype(optionsCreate)
            >(
                module,
                "TfLiteInterpreterOptionsCreate"
            );

        optionsDelete =
            loadSymbol<
                decltype(optionsDelete)
            >(
                module,
                "TfLiteInterpreterOptionsDelete"
            );

        optionsSetThreads =
            loadSymbol<
                decltype(optionsSetThreads)
            >(
                module,
                "TfLiteInterpreterOptionsSetNumThreads"
            );

        optionsAddDelegate =
            loadSymbol<
                decltype(optionsAddDelegate)
            >(
                module,
                "TfLiteInterpreterOptionsAddDelegate"
            );

        interpreterCreate =
            loadSymbol<
                decltype(interpreterCreate)
            >(
                module,
                "TfLiteInterpreterCreate"
            );

        interpreterDelete =
            loadSymbol<
                decltype(interpreterDelete)
            >(
                module,
                "TfLiteInterpreterDelete"
            );

        allocateTensors =
            loadSymbol<
                decltype(allocateTensors)
            >(
                module,
                "TfLiteInterpreterAllocateTensors"
            );

        invoke =
            loadSymbol<
                decltype(invoke)
            >(
                module,
                "TfLiteInterpreterInvoke"
            );

        inputCount =
            loadSymbol<
                decltype(inputCount)
            >(
                module,
                "TfLiteInterpreterGetInputTensorCount"
            );

        outputCount =
            loadSymbol<
                decltype(outputCount)
            >(
                module,
                "TfLiteInterpreterGetOutputTensorCount"
            );

        getInput =
            loadSymbol<
                decltype(getInput)
            >(
                module,
                "TfLiteInterpreterGetInputTensor"
            );

        getOutput =
            loadSymbol<
                decltype(getOutput)
            >(
                module,
                "TfLiteInterpreterGetOutputTensor"
            );

        tensorType =
            loadSymbol<
                decltype(tensorType)
            >(
                module,
                "TfLiteTensorType"
            );

        tensorNumDims =
            loadSymbol<
                decltype(tensorNumDims)
            >(
                module,
                "TfLiteTensorNumDims"
            );

        tensorDim =
            loadSymbol<
                decltype(tensorDim)
            >(
                module,
                "TfLiteTensorDim"
            );

        tensorByteSize =
            loadSymbol<
                decltype(tensorByteSize)
            >(
                module,
                "TfLiteTensorByteSize"
            );

        copyFromBuffer =
            loadSymbol<
                decltype(copyFromBuffer)
            >(
                module,
                "TfLiteTensorCopyFromBuffer"
            );

        copyToBuffer =
            loadSymbol<
                decltype(copyToBuffer)
            >(
                module,
                "TfLiteTensorCopyToBuffer"
            );
    }
};

using FlexCreateFn =
    void* (*)(const wchar_t*);

using FlexGetFn =
    TfLiteDelegate* (*)(void*);

using FlexDestroyFn =
    void (*)(void*);

struct ModelRuntime {
    std::string name;

    TfLiteModel*
        model = nullptr;

    TfLiteInterpreterOptions*
        options = nullptr;

    TfLiteInterpreter*
        interpreter = nullptr;

    int inputSize = 0;
    int outputCount = 0;
};

struct P0Result {
    std::vector<float> tensor;

    bool fallback = false;

    std::string interpolation;

    int x1 = 0;
    int y1 = 0;
    int x2 = 0;
    int y2 = 0;
};

class Pipeline {
public:
    explicit Pipeline(
        const std::wstring& runtimeDirectory
    )
        : runtimeDirectory_(
            runtimeDirectory
        ) {
        initialize();
    }

    ~Pipeline() {
        cleanup();
    }

    Pipeline(
        const Pipeline&
    ) = delete;

    Pipeline& operator=(
        const Pipeline&
    ) = delete;

    const std::string& lastError() const {
        return lastError_;
    }

    const char* tfliteVersion() const {
        return api_.version();
    }

    std::string selfTest() {
        JsonObject root;

        root.setString(
            "status",
            "PASS"
        );

        root.setString(
            "opencv_version",
            CV_VERSION
        );

        root.setString(
            "tensorflow_lite_runtime",
            api_.version()
        );

        root.setInt(
            "models_loaded_n",
            static_cast<long long>(
                models_.size()
            )
        );

        {
            std::vector<float> input(
                UPSTREAM_SIZE *
                UPSTREAM_SIZE *
                3,
                0.0f
            );

            for (
                const char* name :
                {
                    GATE1,
                    MASTER11,
                    GATE2,
                    MASTER12
                }
            ) {
                std::vector<float> output =
                    runModel(
                        name,
                        input
                    );

                if (output.size() != 1) {
                    throw std::runtime_error(
                        std::string(name) +
                        " self-test output count changed."
                    );
                }
            }
        }

        {
            std::vector<float> input(
                P0_OUTPUT_SIZE *
                P0_OUTPUT_SIZE *
                3,
                0.0f
            );

            std::vector<float> output =
                runModel(
                    E03,
                    input
                );

            if (output.size() != 5) {
                throw std::runtime_error(
                    "E03 self-test output count changed."
                );
            }
        }

        root.setBool(
            "all_model_zero_invokes",
            true
        );

        cv::Mat synthetic =
            cv::Mat::zeros(
                480,
                640,
                CV_8UC3
            );

        std::vector<unsigned char>
            encoded;

        if (
            !cv::imencode(
                ".png",
                synthetic,
                encoded
            )
        ) {
            throw std::runtime_error(
                "Could not encode synthetic PNG."
            );
        }

        std::string pipelineResult =
            analyzeEncoded(
                encoded.data(),
                encoded.size()
            );

        root.setRaw(
            "synthetic_pipeline_result",
            pipelineResult
        );

        root.setBool(
            "synthetic_image_pipeline",
            true
        );

        root.setBool(
            "real_image_access",
            false
        );

        root.setBool(
            "locked_test_access",
            false
        );

        return root.str();
    }

    std::string analyzeEncoded(
        const unsigned char* data,
        size_t length
    ) {
        if (
            data == nullptr ||
            length == 0
        ) {
            throw std::runtime_error(
                "Encoded image bytes are empty."
            );
        }

        auto start =
            Clock::now();

        auto decodeStart =
            Clock::now();

        std::vector<unsigned char>
            encoded(
                data,
                data + length
            );

        cv::Mat image =
            cv::imdecode(
                encoded,
                cv::IMREAD_COLOR
            );

        double decodeMs =
            elapsedMs(
                decodeStart
            );

        if (image.empty()) {
            throw std::runtime_error(
                "Image decode failed."
            );
        }

        if (image.type() != CV_8UC3) {
            throw std::runtime_error(
                "Expected CV_8UC3 decoded image."
            );
        }

        JsonObject result;

        result.setInt(
            "original_width",
            image.cols
        );

        result.setInt(
            "original_height",
            image.rows
        );

        result.setNumber(
            "decode_ms",
            decodeMs
        );

        auto resize224Start =
            Clock::now();

        std::vector<float> upstream224 =
            resizeTensorFlowBilinearRgb(
                image,
                UPSTREAM_SIZE,
                UPSTREAM_SIZE
            );

        result.setNumber(
            "resize224_ms",
            elapsedMs(
                resize224Start
            )
        );

        // --------------------------------------------------------
        // GATE 1
        // --------------------------------------------------------

        auto gate1Start =
            Clock::now();

        double gate1Score =
            runScalar(
                GATE1,
                upstream224
            );

        result.setNumber(
            "gate1_ms",
            elapsedMs(
                gate1Start
            )
        );

        result.setNumber(
            "gate1_score",
            gate1Score
        );

        if (
            gate1Score <
            GATE1_ACCEPT
        ) {
            return stop(
                result,
                "GATE1",
                "STOP_NON_FUNDUS",
                "Not recognized as a supported retinal fundus photograph.",
                start
            );
        }

        // --------------------------------------------------------
        // MASTER 11
        // --------------------------------------------------------

        auto master11Start =
            Clock::now();

        double master11Score =
            runScalar(
                MASTER11,
                upstream224
            );

        result.setNumber(
            "master11_ms",
            elapsedMs(
                master11Start
            )
        );

        result.setNumber(
            "master11_score",
            master11Score
        );

        if (
            master11Score <
            MASTER11_ACCEPT
        ) {
            if (
                master11Score >=
                MASTER11_LOWER
            ) {
                return stop(
                    result,
                    "MASTER11",
                    "STOP_MODALITY_BORDERLINE",
                    "Retinal modality is numerically borderline. Use a supported standard color fundus photograph.",
                    start
                );
            }

            return stop(
                result,
                "MASTER11",
                "STOP_UNSUPPORTED_MODALITY",
                "Unsupported retinal imaging modality.",
                start
            );
        }

        // --------------------------------------------------------
        // GATE 2
        // --------------------------------------------------------

        auto gate2Start =
            Clock::now();

        double gate2Score =
            runScalar(
                GATE2,
                upstream224
            );

        result.setNumber(
            "gate2_ms",
            elapsedMs(
                gate2Start
            )
        );

        result.setNumber(
            "gate2_score",
            gate2Score
        );

        if (
            gate2Score <
            GATE2_ACCEPT
        ) {
            runShadowE03(
                image,
                result,
                "GATE2"
            );

            if (
                gate2Score >=
                GATE2_LOWER
            ) {
                return stop(
                    result,
                    "GATE2",
                    "STOP_QUALITY_BORDERLINE",
                    "Image quality is borderline. Recapture or select a clearer fundus image.",
                    start
                );
            }

            return stop(
                result,
                "GATE2",
                "STOP_UNGRADABLE",
                "Image quality is insufficient for safe DR staging.",
                start
            );
        }

        // --------------------------------------------------------
        // MASTER 12
        // --------------------------------------------------------

        auto master12Start =
            Clock::now();

        double master12Score =
            runScalar(
                MASTER12,
                upstream224
            );

        result.setNumber(
            "master12_ms",
            elapsedMs(
                master12Start
            )
        );

        result.setNumber(
            "master12_score",
            master12Score
        );

        if (
            master12Score <
            MASTER12_ACCEPT
        ) {
            runShadowE03(
                image,
                result,
                "MASTER12"
            );

            return stop(
                result,
                "MASTER12",
                "STOP_OUT_OF_SCOPE",
                "Findings may be outside the supported DR-only scope. No DR stage will be issued.",
                start
            );
        }

        // --------------------------------------------------------
        // P0
        // --------------------------------------------------------

        auto p0Start =
            Clock::now();

        P0Result p0 =
            preprocessP0(
                image
            );

        result.setNumber(
            "p0_ms",
            elapsedMs(
                p0Start
            )
        );

        result.setBool(
            "p0_fallback",
            p0.fallback
        );

        result.setString(
            "p0_interpolation",
            p0.interpolation
        );

        result.setInt(
            "p0_crop_x1",
            p0.x1
        );

        result.setInt(
            "p0_crop_y1",
            p0.y1
        );

        result.setInt(
            "p0_crop_x2",
            p0.x2
        );

        result.setInt(
            "p0_crop_y2",
            p0.y2
        );

        // --------------------------------------------------------
        // E03
        // --------------------------------------------------------

        auto e03Start =
            Clock::now();

        std::vector<float>
            probabilities =
                runModel(
                    E03,
                    p0.tensor
                );

        result.setNumber(
            "e03_ms",
            elapsedMs(
                e03Start
            )
        );

        double probabilitySum =
            0.0;

        int highestIndex =
            0;

        for (
            size_t i = 0;
            i < probabilities.size();
            ++i
        ) {
            probabilitySum +=
                probabilities[i];

            if (
                probabilities[i] >
                probabilities[
                    highestIndex
                ]
            ) {
                highestIndex =
                    static_cast<int>(i);
            }
        }

        if (
            std::abs(
                probabilitySum - 1.0
            ) > 0.001
        ) {
            throw std::runtime_error(
                "E03 probability sum failed."
            );
        }

        result.setRaw(
            "e03_probabilities",
            jsonFloatArray(
                probabilities
            )
        );

        result.setInt(
            "e03_index",
            highestIndex
        );

        result.setNumber(
            "e03_probability_sum",
            probabilitySum
        );

        result.setString(
            "final_stage",
            "E03"
        );

        result.setString(
            "final_action",
            "E03_RESULT"
        );

        result.setString(
            "message",
            "Image passed all four IRIS safety guards and reached E03."
        );

        result.setNumber(
            "total_ms",
            elapsedMs(start)
        );

        return result.str();
    }

private:
    std::wstring runtimeDirectory_;

    HMODULE
        tfliteModule_ = nullptr;

    HMODULE
        bridgeModule_ = nullptr;

    TfLiteApi
        api_;

    FlexCreateFn
        flexCreate_ = nullptr;

    FlexGetFn
        flexGet_ = nullptr;

    FlexDestroyFn
        flexDestroy_ = nullptr;

    void*
        flexHolder_ = nullptr;

    TfLiteDelegate*
        flexDelegate_ = nullptr;

    std::map<
        std::string,
        std::unique_ptr<ModelRuntime>
    > models_;

    std::string lastError_;

    void initialize() {
        std::wstring tflitePath =
            joinPath(
                runtimeDirectory_,
                L"tensorflowlite_c.dll"
            );

        std::wstring bridgePath =
            joinPath(
                runtimeDirectory_,
                L"retina_flex_bridge.dll"
            );

        tfliteModule_ =
            LoadLibraryW(
                tflitePath.c_str()
            );

        if (
            tfliteModule_ ==
            nullptr
        ) {
            throw std::runtime_error(
                "Could not load tensorflowlite_c.dll."
            );
        }

        bridgeModule_ =
            LoadLibraryW(
                bridgePath.c_str()
            );

        if (
            bridgeModule_ ==
            nullptr
        ) {
            throw std::runtime_error(
                "Could not load retina_flex_bridge.dll."
            );
        }

        api_.load(
            tfliteModule_
        );

        flexCreate_ =
            loadSymbol<
                FlexCreateFn
            >(
                bridgeModule_,
                "RetinaFlexCreate"
            );

        flexGet_ =
            loadSymbol<
                FlexGetFn
            >(
                bridgeModule_,
                "RetinaFlexGetDelegate"
            );

        flexDestroy_ =
            loadSymbol<
                FlexDestroyFn
            >(
                bridgeModule_,
                "RetinaFlexDestroy"
            );

        std::wstring flexPath =
            joinPath(
                runtimeDirectory_,
                L"tensorflowlite_flex.dll"
            );

        flexHolder_ =
            flexCreate_(
                flexPath.c_str()
            );

        if (
            flexHolder_ ==
            nullptr
        ) {
            throw std::runtime_error(
                "Could not create Flex delegate."
            );
        }

        flexDelegate_ =
            flexGet_(
                flexHolder_
            );

        if (
            flexDelegate_ ==
            nullptr
        ) {
            throw std::runtime_error(
                "Flex delegate is null."
            );
        }

        loadModel(
            GATE1,
            L"IRIS_GATE_MNV2_FLOAT32.tflite",
            224,
            1,
            false
        );

        loadModel(
            MASTER11,
            L"IRIS_MODALITY_FLOAT32.tflite",
            224,
            1,
            false
        );

        loadModel(
            GATE2,
            L"IRIS_GATE2_V2_FLOAT32.tflite",
            224,
            1,
            false
        );

        loadModel(
            MASTER12,
            L"RETINA_MASTER12_V2B_FLOAT32.tflite",
            224,
            1,
            false
        );

        loadModel(
            E03,
            L"FINAL_E03_SELECT_TF_OPS_FLOAT32.tflite",
            512,
            5,
            true
        );
    }

    void loadModel(
        const std::string& name,
        const std::wstring& filename,
        int expectedInputSize,
        int expectedOutputCount,
        bool useFlex
    ) {
        std::wstring widePath =
            joinPath(
                runtimeDirectory_,
                filename
            );

        std::string path =
            wideToUtf8(
                widePath
            );

        auto runtime =
            std::make_unique<
                ModelRuntime
            >();

        runtime->name =
            name;

        runtime->inputSize =
            expectedInputSize;

        runtime->outputCount =
            expectedOutputCount;

        runtime->model =
            api_.modelCreateFromFile(
                path.c_str()
            );

        if (
            runtime->model ==
            nullptr
        ) {
            throw std::runtime_error(
                name +
                " TfLiteModelCreateFromFile failed."
            );
        }

        runtime->options =
            api_.optionsCreate();

        if (
            runtime->options ==
            nullptr
        ) {
            throw std::runtime_error(
                name +
                " options creation failed."
            );
        }

        // Exact Android implementation uses setNumThreads(4).
        api_.optionsSetThreads(
            runtime->options,
            4
        );

        if (useFlex) {
            api_.optionsAddDelegate(
                runtime->options,
                reinterpret_cast<
                    TfLiteOpaqueDelegate*
                >(
                    flexDelegate_
                )
            );
        }

        runtime->interpreter =
            api_.interpreterCreate(
                runtime->model,
                runtime->options
            );

        if (
            runtime->interpreter ==
            nullptr
        ) {
            throw std::runtime_error(
                name +
                " interpreter creation failed."
            );
        }

        if (
            api_.allocateTensors(
                runtime->interpreter
            ) != kTfLiteOk
        ) {
            throw std::runtime_error(
                name +
                " AllocateTensors failed."
            );
        }

        if (
            api_.inputCount(
                runtime->interpreter
            ) != 1
        ) {
            throw std::runtime_error(
                name +
                " input tensor count changed."
            );
        }

        if (
            api_.outputCount(
                runtime->interpreter
            ) != 1
        ) {
            throw std::runtime_error(
                name +
                " output tensor count changed."
            );
        }

        TfLiteTensor* input =
            api_.getInput(
                runtime->interpreter,
                0
            );

        const TfLiteTensor* output =
            api_.getOutput(
                runtime->interpreter,
                0
            );

        if (
            input == nullptr ||
            output == nullptr
        ) {
            throw std::runtime_error(
                name +
                " tensor lookup failed."
            );
        }

        verifyShape(
            input,
            {
                1,
                expectedInputSize,
                expectedInputSize,
                3
            },
            name + " input"
        );

        verifyShape(
            output,
            {
                1,
                expectedOutputCount
            },
            name + " output"
        );

        if (
            api_.tensorType(
                input
            ) != kTfLiteFloat32
        ) {
            throw std::runtime_error(
                name +
                " input dtype changed."
            );
        }

        if (
            api_.tensorType(
                output
            ) != kTfLiteFloat32
        ) {
            throw std::runtime_error(
                name +
                " output dtype changed."
            );
        }

        size_t expectedInputBytes =
            static_cast<size_t>(
                expectedInputSize
            ) *
            expectedInputSize *
            3 *
            sizeof(float);

        size_t expectedOutputBytes =
            static_cast<size_t>(
                expectedOutputCount
            ) *
            sizeof(float);

        if (
            api_.tensorByteSize(
                input
            ) != expectedInputBytes
        ) {
            throw std::runtime_error(
                name +
                " input byte count changed."
            );
        }

        if (
            api_.tensorByteSize(
                output
            ) != expectedOutputBytes
        ) {
            throw std::runtime_error(
                name +
                " output byte count changed."
            );
        }

        models_.emplace(
            name,
            std::move(runtime)
        );
    }

    void verifyShape(
        const TfLiteTensor* tensor,
        std::initializer_list<int>
            expected,
        const std::string& label
    ) {
        int dims =
            api_.tensorNumDims(
                tensor
            );

        if (
            dims !=
            static_cast<int>(
                expected.size()
            )
        ) {
            throw std::runtime_error(
                label +
                " rank mismatch."
            );
        }

        int index =
            0;

        for (int expectedDim : expected) {

            if (
                api_.tensorDim(
                    tensor,
                    index
                ) != expectedDim
            ) {
                throw std::runtime_error(
                    label +
                    " shape mismatch."
                );
            }

            ++index;
        }
    }

    std::vector<float> runModel(
        const std::string& name,
        const std::vector<float>& input
    ) {
        auto found =
            models_.find(
                name
            );

        if (
            found ==
            models_.end()
        ) {
            throw std::runtime_error(
                "Model not loaded: " +
                name
            );
        }

        ModelRuntime&
            model =
                *found->second;

        size_t expectedFloats =
            static_cast<size_t>(
                model.inputSize
            ) *
            model.inputSize *
            3;

        if (
            input.size() !=
            expectedFloats
        ) {
            throw std::runtime_error(
                name +
                " input float count mismatch."
            );
        }

        TfLiteTensor* inputTensor =
            api_.getInput(
                model.interpreter,
                0
            );

        if (
            api_.copyFromBuffer(
                inputTensor,
                input.data(),
                input.size() *
                    sizeof(float)
            ) != kTfLiteOk
        ) {
            throw std::runtime_error(
                name +
                " input copy failed."
            );
        }

        if (
            api_.invoke(
                model.interpreter
            ) != kTfLiteOk
        ) {
            throw std::runtime_error(
                name +
                " Invoke failed."
            );
        }

        const TfLiteTensor*
            outputTensor =
                api_.getOutput(
                    model.interpreter,
                    0
                );

        std::vector<float>
            output(
                model.outputCount
            );

        if (
            api_.copyToBuffer(
                outputTensor,
                output.data(),
                output.size() *
                    sizeof(float)
            ) != kTfLiteOk
        ) {
            throw std::runtime_error(
                name +
                " output copy failed."
            );
        }

        for (float value : output) {
            if (
                !std::isfinite(
                    value
                )
            ) {
                throw std::runtime_error(
                    name +
                    " produced non-finite output."
                );
            }
        }

        return output;
    }

    double runScalar(
        const std::string& name,
        const std::vector<float>& input
    ) {
        std::vector<float>
            output =
                runModel(
                    name,
                    input
                );

        if (
            output.size() != 1
        ) {
            throw std::runtime_error(
                name +
                " scalar output changed."
            );
        }

        return output[0];
    }

    std::vector<float>
    resizeTensorFlowBilinearRgb(
        const cv::Mat& bgr,
        int outWidth,
        int outHeight
    ) {
        int inHeight =
            bgr.rows;

        int inWidth =
            bgr.cols;

        if (
            bgr.type() !=
            CV_8UC3
        ) {
            throw std::runtime_error(
                "resizeTensorFlowBilinearRgb expects CV_8UC3."
            );
        }

        cv::Mat source =
            bgr.isContinuous()
            ? bgr
            : bgr.clone();

        const unsigned char*
            src =
                source.ptr<
                    unsigned char
                >(0);

        std::vector<int>
            x0(
                outWidth
            );

        std::vector<int>
            x1(
                outWidth
            );

        std::vector<double>
            wx(
                outWidth
            );

        for (
            int x = 0;
            x < outWidth;
            ++x
        ) {
            double sourceX =
                (
                    (x + 0.5) *
                    inWidth /
                    static_cast<double>(
                        outWidth
                    )
                ) -
                0.5;

            sourceX =
                std::max(
                    0.0,
                    std::min(
                        sourceX,
                        inWidth - 1.0
                    )
                );

            int left =
                static_cast<int>(
                    std::floor(
                        sourceX
                    )
                );

            int right =
                std::min(
                    left + 1,
                    inWidth - 1
                );

            x0[x] =
                left;

            x1[x] =
                right;

            wx[x] =
                sourceX -
                left;
        }

        std::vector<float>
            output(
                outHeight *
                outWidth *
                3
            );

        const int
            sourceChannels[3] =
                {
                    2,
                    1,
                    0
                };

        for (
            int y = 0;
            y < outHeight;
            ++y
        ) {
            double sourceY =
                (
                    (y + 0.5) *
                    inHeight /
                    static_cast<double>(
                        outHeight
                    )
                ) -
                0.5;

            sourceY =
                std::max(
                    0.0,
                    std::min(
                        sourceY,
                        inHeight - 1.0
                    )
                );

            int top =
                static_cast<int>(
                    std::floor(
                        sourceY
                    )
                );

            int bottom =
                std::min(
                    top + 1,
                    inHeight - 1
                );

            double wy =
                sourceY -
                top;

            for (
                int x = 0;
                x < outWidth;
                ++x
            ) {
                int left =
                    x0[x];

                int right =
                    x1[x];

                double weightX =
                    wx[x];

                int outputBase =
                    (
                        y *
                        outWidth +
                        x
                    ) *
                    3;

                for (
                    int outChannel = 0;
                    outChannel < 3;
                    ++outChannel
                ) {
                    int sourceChannel =
                        sourceChannels[
                            outChannel
                        ];

                    auto pixel =
                        [&](int py,
                            int px,
                            int channel)
                        -> double {
                            return static_cast<
                                double
                            >(
                                src[
                                    (
                                        (
                                            py *
                                            inWidth +
                                            px
                                        ) *
                                        3
                                    ) +
                                    channel
                                ]
                            );
                        };

                    double p00 =
                        pixel(
                            top,
                            left,
                            sourceChannel
                        );

                    double p01 =
                        pixel(
                            top,
                            right,
                            sourceChannel
                        );

                    double p10 =
                        pixel(
                            bottom,
                            left,
                            sourceChannel
                        );

                    double p11 =
                        pixel(
                            bottom,
                            right,
                            sourceChannel
                        );

                    double topValue =
                        p00 +
                        (
                            p01 -
                            p00
                        ) *
                        weightX;

                    double bottomValue =
                        p10 +
                        (
                            p11 -
                            p10
                        ) *
                        weightX;

                    output[
                        outputBase +
                        outChannel
                    ] =
                        static_cast<float>(
                            topValue +
                            (
                                bottomValue -
                                topValue
                            ) *
                            wy
                        );
                }
            }
        }

        return output;
    }

    P0Result preprocessP0(
        const cv::Mat& image
    ) {
        cv::Mat gray;
        cv::Mat mask;
        cv::Mat labels;
        cv::Mat stats;
        cv::Mat centroids;
        cv::Mat cropped;
        cv::Mat squared;
        cv::Mat resized;
        cv::Mat rgb;

        int originalHeight =
            image.rows;

        int originalWidth =
            image.cols;

        cv::cvtColor(
            image,
            gray,
            cv::COLOR_BGR2GRAY
        );

        cv::threshold(
            gray,
            mask,
            P0_BACKGROUND_THRESHOLD,
            255.0,
            cv::THRESH_BINARY
        );

        cv::Mat kernel =
            cv::getStructuringElement(
                cv::MORPH_ELLIPSE,
                cv::Size(
                    5,
                    5
                )
            );

        cv::morphologyEx(
            mask,
            mask,
            cv::MORPH_CLOSE,
            kernel,
            cv::Point(
                -1,
                -1
            ),
            2
        );

        int numberOfLabels =
            cv::connectedComponentsWithStats(
                mask,
                labels,
                stats,
                centroids,
                8,
                CV_32S
            );

        int x1;
        int y1;
        int x2;
        int y2;

        bool fallback =
            false;

        if (
            numberOfLabels <= 1
        ) {
            x1 = 0;
            y1 = 0;
            x2 = originalWidth;
            y2 = originalHeight;

            fallback =
                true;
        }
        else {
            int largestLabel =
                1;

            int largestArea =
                stats.at<int>(
                    1,
                    cv::CC_STAT_AREA
                );

            for (
                int label = 2;
                label < numberOfLabels;
                ++label
            ) {
                int area =
                    stats.at<int>(
                        label,
                        cv::CC_STAT_AREA
                    );

                if (
                    area >
                    largestArea
                ) {
                    largestArea =
                        area;

                    largestLabel =
                        label;
                }
            }

            int x =
                stats.at<int>(
                    largestLabel,
                    cv::CC_STAT_LEFT
                );

            int y =
                stats.at<int>(
                    largestLabel,
                    cv::CC_STAT_TOP
                );

            int boxWidth =
                stats.at<int>(
                    largestLabel,
                    cv::CC_STAT_WIDTH
                );

            int boxHeight =
                stats.at<int>(
                    largestLabel,
                    cv::CC_STAT_HEIGHT
                );

            long long detectedArea =
                static_cast<long long>(
                    boxWidth
                ) *
                boxHeight;

            long long imageArea =
                static_cast<long long>(
                    originalWidth
                ) *
                originalHeight;

            double bboxFraction =
                static_cast<double>(
                    detectedArea
                ) /
                static_cast<double>(
                    std::max<
                        long long
                    >(
                        imageArea,
                        1
                    )
                );

            if (
                bboxFraction <
                0.20
            ) {
                x1 = 0;
                y1 = 0;
                x2 = originalWidth;
                y2 = originalHeight;

                fallback =
                    true;
            }
            else {
                // Java Math.rint follows nearest-even behavior.
                int margin =
                    static_cast<int>(
                        std::nearbyint(
                            std::max(
                                boxWidth,
                                boxHeight
                            ) *
                            P0_FOV_MARGIN_FRACTION
                        )
                    );

                x1 =
                    std::max(
                        0,
                        x - margin
                    );

                y1 =
                    std::max(
                        0,
                        y - margin
                    );

                x2 =
                    std::min(
                        originalWidth,
                        x +
                        boxWidth +
                        margin
                    );

                y2 =
                    std::min(
                        originalHeight,
                        y +
                        boxHeight +
                        margin
                    );
            }
        }

        if (
            x2 <= x1 ||
            y2 <= y1
        ) {
            cropped =
                image.clone();

            x1 = 0;
            y1 = 0;
            x2 = originalWidth;
            y2 = originalHeight;

            fallback =
                true;
        }
        else {
            cv::Rect cropRect(
                x1,
                y1,
                x2 - x1,
                y2 - y1
            );

            cropped =
                image(
                    cropRect
                ).clone();

            if (
                cropped.empty()
            ) {
                cropped =
                    image.clone();

                x1 = 0;
                y1 = 0;
                x2 = originalWidth;
                y2 = originalHeight;

                fallback =
                    true;
            }
        }

        int cropHeight =
            cropped.rows;

        int cropWidth =
            cropped.cols;

        int side =
            std::max(
                cropHeight,
                cropWidth
            );

        int padTop =
            (
                side -
                cropHeight
            ) /
            2;

        int padBottom =
            side -
            cropHeight -
            padTop;

        int padLeft =
            (
                side -
                cropWidth
            ) /
            2;

        int padRight =
            side -
            cropWidth -
            padLeft;

        cv::copyMakeBorder(
            cropped,
            squared,
            padTop,
            padBottom,
            padLeft,
            padRight,
            cv::BORDER_CONSTANT,
            cv::Scalar(
                0,
                0,
                0
            )
        );

        int interpolation =
            (
                squared.cols >
                    P0_OUTPUT_SIZE ||
                squared.rows >
                    P0_OUTPUT_SIZE
            )
            ? cv::INTER_AREA
            : cv::INTER_CUBIC;

        cv::resize(
            squared,
            resized,
            cv::Size(
                P0_OUTPUT_SIZE,
                P0_OUTPUT_SIZE
            ),
            0.0,
            0.0,
            interpolation
        );

        if (
            resized.rows !=
                P0_OUTPUT_SIZE ||
            resized.cols !=
                P0_OUTPUT_SIZE ||
            resized.type() !=
                CV_8UC3
        ) {
            throw std::runtime_error(
                "Unexpected P0 output."
            );
        }

        cv::cvtColor(
            resized,
            rgb,
            cv::COLOR_BGR2RGB
        );

        if (
            !rgb.isContinuous()
        ) {
            rgb =
                rgb.clone();
        }

        size_t count =
            static_cast<size_t>(
                P0_OUTPUT_SIZE
            ) *
            P0_OUTPUT_SIZE *
            3;

        std::vector<float>
            tensor(
                count
            );

        const unsigned char*
            pixels =
                rgb.ptr<
                    unsigned char
                >(0);

        for (
            size_t i = 0;
            i < count;
            ++i
        ) {
            tensor[i] =
                static_cast<float>(
                    pixels[i]
                );
        }

        P0Result result;

        result.tensor =
            std::move(
                tensor
            );

        result.fallback =
            fallback;

        result.interpolation =
            interpolation ==
                cv::INTER_AREA
            ? "INTER_AREA"
            : "INTER_CUBIC";

        result.x1 = x1;
        result.y1 = y1;
        result.x2 = x2;
        result.y2 = y2;

        return result;
    }

    void runShadowE03(
        const cv::Mat& image,
        JsonObject& result,
        const std::string& rejectedAt
    ) {
        result.setString(
            "shadow_e03_rejected_at",
            rejectedAt
        );

        try {
            auto p0Start =
                Clock::now();

            P0Result p0 =
                preprocessP0(
                    image
                );

            result.setNumber(
                "shadow_p0_ms",
                elapsedMs(
                    p0Start
                )
            );

            auto e03Start =
                Clock::now();

            std::vector<float>
                probabilities =
                    runModel(
                        E03,
                        p0.tensor
                    );

            result.setNumber(
                "shadow_e03_ms",
                elapsedMs(
                    e03Start
                )
            );

            double probabilitySum =
                0.0;

            int highestIndex =
                0;

            for (
                size_t i = 0;
                i < probabilities.size();
                ++i
            ) {
                probabilitySum +=
                    probabilities[i];

                if (
                    probabilities[i] >
                    probabilities[
                        highestIndex
                    ]
                ) {
                    highestIndex =
                        static_cast<int>(
                            i
                        );
                }
            }

            if (
                std::abs(
                    probabilitySum -
                    1.0
                ) > 0.001
            ) {
                throw std::runtime_error(
                    "Shadow E03 probability sum failed."
                );
            }

            const char*
                labels[] = {
                    "No apparent DR",
                    "Mild NPDR",
                    "Moderate NPDR",
                    "Severe NPDR",
                    "Proliferative DR"
                };

            result.setRaw(
                "shadow_e03_probabilities",
                jsonFloatArray(
                    probabilities
                )
            );

            result.setInt(
                "shadow_e03_index",
                highestIndex
            );

            result.setString(
                "shadow_e03_label",
                labels[
                    highestIndex
                ]
            );

            result.setNumber(
                "shadow_e03_probability_sum",
                probabilitySum
            );

            result.setBool(
                "shadow_e03_research_only",
                true
            );
        }
        catch (
            const std::exception& error
        ) {
            result.setString(
                "shadow_e03_error",
                error.what()
            );
        }
    }

    std::string stop(
        JsonObject& result,
        const std::string& stage,
        const std::string& action,
        const std::string& message,
        Clock::time_point start
    ) {
        result.setString(
            "final_stage",
            stage
        );

        result.setString(
            "final_action",
            action
        );

        result.setString(
            "message",
            message
        );

        result.setNumber(
            "total_ms",
            elapsedMs(
                start
            )
        );

        return result.str();
    }

    void cleanup() {
        for (
            auto& entry :
            models_
        ) {
            ModelRuntime&
                model =
                    *entry.second;

            if (
                model.interpreter !=
                nullptr
            ) {
                api_.interpreterDelete(
                    model.interpreter
                );

                model.interpreter =
                    nullptr;
            }

            if (
                model.options !=
                nullptr
            ) {
                api_.optionsDelete(
                    model.options
                );

                model.options =
                    nullptr;
            }

            if (
                model.model !=
                nullptr
            ) {
                api_.modelDelete(
                    model.model
                );

                model.model =
                    nullptr;
            }
        }

        models_.clear();

        if (
            flexHolder_ !=
            nullptr &&
            flexDestroy_ !=
            nullptr
        ) {
            flexDestroy_(
                flexHolder_
            );

            flexHolder_ =
                nullptr;

            flexDelegate_ =
                nullptr;
        }

        if (
            bridgeModule_ !=
            nullptr
        ) {
            FreeLibrary(
                bridgeModule_
            );

            bridgeModule_ =
                nullptr;
        }

        if (
            tfliteModule_ !=
            nullptr
        ) {
            FreeLibrary(
                tfliteModule_
            );

            tfliteModule_ =
                nullptr;
        }
    }
};

char* duplicateString(
    const std::string& value
) {
    size_t bytes =
        value.size() + 1;

    char* result =
        static_cast<char*>(
            std::malloc(
                bytes
            )
        );

    if (
        result ==
        nullptr
    ) {
        return nullptr;
    }

    std::memcpy(
        result,
        value.c_str(),
        bytes
    );

    return result;
}

}  // namespace

extern "C"
__declspec(dllexport)
unsigned int
RetinaPipelineAbiVersion() {
    return 1;
}

extern "C"
__declspec(dllexport)
const char*
RetinaPipelineOpenCvVersion() {
    return CV_VERSION;
}

extern "C"
__declspec(dllexport)
void*
RetinaPipelineCreate(
    const wchar_t* runtimeDirectory
) {
    if (
        runtimeDirectory ==
        nullptr ||
        runtimeDirectory[0] ==
        L'\0'
    ) {
        return nullptr;
    }

    try {
        return new Pipeline(
            runtimeDirectory
        );
    }
    catch (...) {
        return nullptr;
    }
}

extern "C"
__declspec(dllexport)
void
RetinaPipelineDestroy(
    void* handle
) {
    if (
        handle ==
        nullptr
    ) {
        return;
    }

    delete reinterpret_cast<
        Pipeline*
    >(
        handle
    );
}

extern "C"
__declspec(dllexport)
int
RetinaPipelineSelfTest(
    void* handle,
    char** outputJson
) {
    if (
        handle ==
        nullptr ||
        outputJson ==
        nullptr
    ) {
        return 10;
    }

    *outputJson =
        nullptr;

    try {
        Pipeline* pipeline =
            reinterpret_cast<
                Pipeline*
            >(
                handle
            );

        std::string json =
            pipeline->selfTest();

        *outputJson =
            duplicateString(
                json
            );

        if (
            *outputJson ==
            nullptr
        ) {
            return 11;
        }

        return 0;
    }
    catch (
        const std::exception& error
    ) {
        JsonObject failure;

        failure.setString(
            "status",
            "FAIL"
        );

        failure.setString(
            "error",
            error.what()
        );

        *outputJson =
            duplicateString(
                failure.str()
            );

        return 12;
    }
    catch (...) {
        return 13;
    }
}

extern "C"
__declspec(dllexport)
int
RetinaPipelineAnalyzeEncoded(
    void* handle,
    const unsigned char* bytes,
    size_t length,
    char** outputJson
) {
    if (
        handle ==
        nullptr ||
        bytes ==
        nullptr ||
        length == 0 ||
        outputJson ==
        nullptr
    ) {
        return 20;
    }

    *outputJson =
        nullptr;

    try {
        Pipeline* pipeline =
            reinterpret_cast<
                Pipeline*
            >(
                handle
            );

        std::string json =
            pipeline->analyzeEncoded(
                bytes,
                length
            );

        *outputJson =
            duplicateString(
                json
            );

        if (
            *outputJson ==
            nullptr
        ) {
            return 21;
        }

        return 0;
    }
    catch (
        const std::exception& error
    ) {
        JsonObject failure;

        failure.setString(
            "status",
            "FAIL"
        );

        failure.setString(
            "error",
            error.what()
        );

        *outputJson =
            duplicateString(
                failure.str()
            );

        return 22;
    }
    catch (...) {
        return 23;
    }
}

extern "C"
__declspec(dllexport)
void
RetinaPipelineFreeString(
    char* value
) {
    std::free(
        value
    );
}
