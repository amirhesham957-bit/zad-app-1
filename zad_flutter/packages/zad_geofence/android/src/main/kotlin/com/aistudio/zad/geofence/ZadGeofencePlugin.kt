package com.aistudio.zad.geofence

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** يوصّل النطاقات وصندوق الأحداث وحالة الأماكن لـ Dart. */
class ZadGeofencePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        if (Delivery.uiChannel === channel) Delivery.uiChannel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Delivery.uiChannel = channel
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        Delivery.uiChannel = channel
    }

    override fun onDetachedFromActivityForConfigChanges() {}

    override fun onDetachedFromActivity() {
        if (Delivery.uiChannel === channel) Delivery.uiChannel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "hasBackgroundPermission" -> result.success(Fences.hasBackgroundPermission(context))
                "register" -> Fences.register(context, call.argument<String>("fences") ?: "[]") { error ->
                    if (error == null) result.success(null) else result.error("register_failed", error, null)
                }
                "clear" -> {
                    Fences.clear(context)
                    result.success(null)
                }
                "scheduleNight" -> {
                    Fences.scheduleNight(context, call.argument<Number>("at")!!.toLong())
                    result.success(null)
                }
                "cancelNight" -> {
                    Fences.cancelNight(context)
                    result.success(null)
                }
                "peek" -> result.success(PlaceEventStore.get(context).peek())
                "acknowledge" -> {
                    val keys = call.argument<List<Number>>("keys").orEmpty().map { it.toLong() }.toSet()
                    PlaceEventStore.get(context).acknowledge(keys)
                    result.success(null)
                }
                "readState" -> result.success(Fences.prefs(context).getString(Fences.STATE_KEY, null))
                "writeState" -> {
                    Fences.prefs(context).edit().putString(Fences.STATE_KEY, call.argument<String>("state")).commit()
                    result.success(null)
                }
                "registerBackgroundHandle" -> {
                    val handle = call.argument<Number>("handle")?.toLong() ?: 0L
                    if (handle != 0L) Delivery.saveCallbackHandle(context, handle)
                    result.success(null)
                }
                "backgroundDone" -> {
                    Delivery.headlessFinished()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("zad_geofence", e.message, null)
        }
    }

    private companion object {
        const val CHANNEL = "com.aistudio.zad/geofence"
    }
}
