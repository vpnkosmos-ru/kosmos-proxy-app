package ru.kosmosproxy.app

import android.util.Log
import ru.kosmosproxy.app.bg.BoxService
//import ru.kosmosproxy.app.bg.BoxService.Companion.workingDir
import ru.kosmosproxy.app.constant.Status
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

import com.hiddify.core.libbox.Libbox
import com.hiddify.core.mobile.Mobile
import com.hiddify.core.mobile.SetupOptions
import ru.kosmosproxy.app.bg.Bugs
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.File

class MethodHandler(private val scope: CoroutineScope) : FlutterPlugin,
    MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null

    companion object {
        const val TAG = "A/MethodHandler"
        const val channelName = "ru.kosmosproxy.app/method"

        enum class Trigger(val method: String) {
            Setup("setup"),
            Start("start"),
            Stop("stop"),
            Restart("restart"),
            AddGrpcClientPublicKey("add_grpc_client_public_key"),
            GetGrpcServerPublicKey("get_grpc_server_public_key"),
            GetServiceStatus("get_service_status"),

        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            channelName,
        )
        channel!!.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            Trigger.AddGrpcClientPublicKey.method -> {
                GlobalScope.launch {
                    result.runCatching {
                        val args = call.arguments as Map<*, *>
                        val clientPub = args["clientPublicKey"] as ByteArray
//                        Mobile.addGrpcClientPublicKey(clientPub)
                        Settings.grpcFlutterPublicKey = clientPub
                        success("")

                    }
                }
            }

            Trigger.GetGrpcServerPublicKey.method -> {
                GlobalScope.launch {
                    result.runCatching {
                        result.success(Mobile.getServerPublicKey())
                    }
                }
            }

            Trigger.GetServiceStatus.method -> {
                // Read-only lifecycle probe used after Flutter resumes. It does
                // not start, stop, or rebind the VPN service.
                result.success(MainActivity.instance.serviceStatus.value?.name ?: Status.Stopped.name)
            }

            Trigger.Setup.method -> {
                GlobalScope.launch {
                    try {
                        val args = call.arguments as Map<*, *>
                        Settings.baseDir = args["baseDir"] as String
                        Settings.workingDir = args["workingDir"] as String
                        Settings.tempDir = args["tempDir"] as String
                        Settings.debugMode = args["debug"] as Boolean? ?: false
                        val mode = args["mode"] as Int
                        val grpcPort = args["grpcPort"] as Int
                        Log.d("debugmode","${Settings.debugMode}")
                        Mobile.setup(
                            SetupOptions().also {
                                it.basePath = Settings.baseDir
                                it.workingDir = Settings.workingDir
                                it.tempDir = Settings.tempDir
                                it.fixAndroidStack = Bugs.fixAndroidStack
                                it.mode=mode.toLong()
                                it.listen= "127.0.0.1:" + grpcPort
                                it.secret=""
                                it.debug = Settings.debugMode
                            },null)

//                      Libbox.setup(Settings.baseDir, Settings.workingDir, Settings.tempDir, false)
                        Libbox.redirectStderr(File(Settings.workingDir, "stderr2.log").path)
                        result.success("")
                    } catch (exception: Exception) {
                        result.fail(Trigger.Setup, exception)
                    }
                }
            }


            Trigger.Start.method -> {
                scope.launch {
                    try {
                        val args = call.arguments as Map<*, *>
                        Settings.activeConfigPath = args["path"] as String? ?: ""
                        Settings.activeProfileName = args["name"] as String? ?: ""
                        Settings.debugMode = args["debug"] as Boolean? ?: false
                        Settings.grpcServiceModePort = args["grpcPort"] as Int

                        val mainActivity = MainActivity.instance
//                        val started = mainActivity.serviceStatus.value == Status.Started
//                        if (started) {
//                            Log.w(TAG, "service is already running")
//                            return@launch success(true)
//                        }
                        Settings.startCoreAfterStartingService = false

                        mainActivity.startService()
                        result.success(true)
                    } catch (exception: Exception) {
                        result.fail(Trigger.Start, exception)
                    }
                }
            }

            Trigger.Stop.method -> {
                scope.launch {
                    try {
                        val mainActivity = MainActivity.instance
                        val started = mainActivity.serviceStatus.value == Status.Started
                        if (!started) {
                            Log.w(TAG, "service is not running")
                            //    return@launch success(true)
                        }
                        BoxService.stop()
                        result.success(true)
                    } catch (exception: Exception) {
                        result.fail(Trigger.Stop, exception)
                    }
                }
            }

//            Trigger.Restart.method -> {
//                scope.launch(Dispatchers.IO) {
//                    result.runCatching {
//                        val args = call.arguments as Map<*, *>
//                        Settings.activeConfigPath = args["path"] as String? ?: ""
//                        Settings.activeProfileName = args["name"] as String? ?: ""
//                        val mainActivity = MainActivity.instance
//                        val started = mainActivity.serviceStatus.value == Status.Started
//                        if (!started) return@launch success(true)
//                        val restart = Settings.rebuildServiceMode()
//                        if (restart) {
//                            mainActivity.reconnect()
//                            BoxService.stop()
//                            delay(1000L)
//                            mainActivity.startService()
//                            return@launch success(true)
//                        }
//                        runCatching {
//                            Libbox.newStandaloneCommandClient().serviceReload()
//                            success(true)
//                        }.onFailure {
//                            error(it)
//                        }
//                    }
//                }
//            }

            else -> result.notImplemented()
        }
    }

    private fun MethodChannel.Result.fail(trigger: Trigger, exception: Exception) {
        // Never use Kotlin's error() here: this runs on a Flutter coroutine and
        // would crash the Android process instead of returning PlatformException.
        Log.e(TAG, "${trigger.method} failed", exception)
        error("CORE_${trigger.name.uppercase()}", "VPN core operation failed", null)
    }
}
