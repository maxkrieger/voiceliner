package chat.saga.voice_outliner

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import org.vosk.Recognizer
import org.vosk.Model
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechStreamService
import java.io.File
import java.io.FileInputStream

class VOListener(val onRes: (String?) -> Unit, val onFinalRes: (String?) -> Unit) :
    RecognitionListener {
    public override fun onTimeout() {
    }

    public override fun onError(exception: java.lang.Exception?) {
        onFinalResult(null)
    }

    public override fun onFinalResult(hypothesis: String?) {
        if (hypothesis != null) {
            val text = JSONObject(hypothesis).getString("text").toString()
            onFinalRes(text)
        } else onFinalRes(null)
    }

    public override fun onPartialResult(hypothesis: String?) {
    }

    public override fun onResult(hypothesis: String?) {
        if (hypothesis != null) {
            val text = JSONObject(hypothesis).getString("text").toString()
            onRes(text)
        } else onRes(null)
    }
}

class MainActivity : FlutterActivity() {
    private val CHANNEL = "voiceoutliner.saga.chat/androidtx"
    private var model: Model? = null;

    /**
     * @param path
     * Unzipped model path
     */
    private fun initModel(call: MethodCall, result: MethodChannel.Result) {
        try {
            val path = call.argument<String>("path")
            if (path == null) {
                result.error("Null path provided", "Cannot transcribe null path", null)
                return
            }
            this.model = Model(path)
            result.success(null);

        } catch (e: Exception) {
            result.error("Couldn't initialize model", e.toString(), null);
        }
    }

    private fun transcribe(call: MethodCall, result: MethodChannel.Result) {
        try {
            val path = call.argument<String>("path")
            if (path == null) {
                result.error("Null path provided", "Cannot transcribe null path", null)
                return
            }
            if (this.model == null) {
                result.error("Model uninitialized", null, null)
                return
            }
            val file = File(path)
            val inputStream = FileInputStream(file)
            val recognizer = Recognizer(this.model, 44100F);
            val speechStreamService = SpeechStreamService(recognizer, inputStream, 44100F)
            val results = arrayListOf<String>()
            speechStreamService.start(VOListener({ res ->
                if (res != null) {
                    results.add(res)
                }
            }, { res ->
                if (res != null) {
                    results.add(res)
                }
                if (results.isEmpty() || results.joinToString("").isBlank() ) {
                    result.success(null)
                } else {
                    result.success(results.joinToString(" "))
                }
                speechStreamService.stop()
            }))
        } catch (e: Exception) {
            result.error("Couldn't transcribe", e.toString(), null)
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "transcribe" -> transcribe(call, result)
                "initModel" -> initModel(call, result)
                else -> result.notImplemented()
            }
        }
    }
}
