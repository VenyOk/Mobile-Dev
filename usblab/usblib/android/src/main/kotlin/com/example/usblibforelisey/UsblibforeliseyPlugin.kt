package com.example.usblibforelisey


import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbAccessory
import android.hardware.usb.UsbManager
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.FileInputStream
import java.io.FileOutputStream

private const val ACTION_USB_PERMISSION = "com.example.usblibforelisey.USB_PERMISSION"

private val pendingIntentFlag =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
    } else {
        PendingIntent.FLAG_UPDATE_CURRENT
    }

private fun pendingPermissionIntent(context: Context) =
    PendingIntent.getBroadcast(context, 0, Intent(ACTION_USB_PERMISSION), pendingIntentFlag)

/** UsblibforeliseyPlugin */
class UsblibforeliseyPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var applicationContext: Context? = null
    private var usbManager: UsbManager? = null
    private var inputStream: FileInputStream? = null
    private var outputStream: FileOutputStream? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "usblibforelisey")
        channel.setMethodCallHandler(this)
        applicationContext = flutterPluginBinding.applicationContext
        usbManager = applicationContext?.getSystemService(Context.USB_SERVICE) as UsbManager
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasAccessoryConnected" -> {
                Log.d("usblibforelisey", "inside hasAccessoryConnected")
                val manager = usbManager ?: return result.error("IllegalState", "usbManager null", null)
                val usbDeviceList = manager.accessoryList
                Log.d("usblibforelisey", "detected ${usbDeviceList?.size} accs")
                result.success(usbDeviceList != null && usbDeviceList.isNotEmpty())
            }

            "hasPermission" -> {
                Log.d("usblibforelisey", "inside hasPermission")
                val manager =
                    usbManager ?: return result.error("IllegalState", "usbManager null", null)
                val index = call.argument<Int?>("index")
                val accessory = manager.accessoryList[index!!]
                result.success(manager.hasPermission(accessory))
            }

            "requestPermission" -> {
                Log.d("usblibforelisey", "inside requestPermission")

                val context = applicationContext ?: return result.error(
                    "IllegalState",
                    "applicationContext null",
                    null
                )
                val manager =
                    usbManager ?: return result.error("IllegalState", "usbManager null", null)
                val index: Int? = call.argument<Int?>("index")
                val accessory: UsbAccessory = manager.accessoryList[index!!]
                if (manager.hasPermission(accessory)) {
                    result.success(true)
                } else {
                    val receiver = object : BroadcastReceiver() {
                        override fun onReceive(context: Context, intent: Intent) {
                            context.unregisterReceiver(this)
                            val granted =
                                (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false))
                            result.success(granted);
                        }
                    }
                    context.registerReceiver(receiver, IntentFilter(ACTION_USB_PERMISSION))
                    manager.requestPermission(accessory, pendingPermissionIntent(context))
                }
            }

            "connect" -> {
                Log.d("usblibforelisey", "inside connect")

                try {
                    val manager =
                        usbManager ?: return result.error("IllegalState", "usbManager null", null)
                    
                    val accessoryList = manager.accessoryList
                    if (accessoryList == null || accessoryList.isEmpty()) {
                        return result.error("NO_ACCESSORY", "No USB accessory found", null)
                    }
                    
                    val accessory = accessoryList.first()
                    
                    // Закрываем предыдущие потоки, если они открыты
                    inputStream?.close()
                    outputStream?.close()
                    inputStream = null
                    outputStream = null

                    val pd = manager.openAccessory(accessory)
                    inputStream = FileInputStream(pd.fileDescriptor)
                    outputStream = FileOutputStream(pd.fileDescriptor)
                    result.success(true)
                } catch (e: Exception) {
                    Log.e("usblibforelisey", "Error connecting: ${e.message}")
                    result.error("CONNECT_ERROR", e.message, null)
                }
            }

            "read" -> {
                Log.d("usblibforelisey", "inside read")

                try {
                    val buf = ByteArray(1024)
                    val bytesRead = inputStream?.read(buf) ?: -1
                    if (bytesRead > 0) {
                        result.success(buf.copyOf(bytesRead))
                    } else {
                        result.success(ByteArray(0))
                    }
                } catch (e: Exception) {
                    Log.e("usblibforelisey", "Error reading: ${e.message}")
                    result.error("READ_ERROR", e.message, null)
                }
            }

            "write" -> {
                Log.d("usblibforelisey", "inside write")

                try {
                    val data: ByteArray? = call.argument<ByteArray?>("data")
                    if (data != null && data.isNotEmpty()) {
                        outputStream?.write(data)
                        outputStream?.flush()  // Убеждаемся, что данные отправлены
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                } catch (e: Exception) {
                    Log.e("usblibforelisey", "Error writing: ${e.message}")
                    result.error("WRITE_ERROR", e.message, null)
                }
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
