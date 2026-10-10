package app.oddo.oddo

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.graphics.PointF
import android.media.ExifInterface
import android.media.FaceDetector
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val cameraWorker = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "app.oddo.oddo/diary_reminder").setMethodCallHandler { call, result ->
            if (call.method != "configure") {
                result.notImplemented()
            } else {
                try {
                    result.success(DiaryReminder.configure(this,
                        call.argument<Boolean>("enabled") ?: false,
                        call.argument<Int>("hour") ?: 21,
                        call.argument<Int>("minute") ?: 0))
                } catch (_: Exception) {
                    result.error("unavailable", "Reminder configuration unavailable", null)
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "app.oddo.oddo/camera_guidance").setMethodCallHandler { call, result ->
            val path = call.arguments as? String
            if (call.method != "inspect") {
                result.notImplemented()
            } else if (path == null) {
                result.error("unavailable", "Camera inspection unavailable", null)
            } else {
                cameraWorker.execute {
                    val values = try { inspectCamera(path) } catch (_: Exception) { null }
                    runOnUiThread { result.success(values) }
                }
            }
        }
    }

    private fun inspectCamera(path: String): Map<String, Double?>? {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, options)
        options.inJustDecodeBounds = false
        options.inSampleSize = 1
        while (maxOf(options.outWidth, options.outHeight) / options.inSampleSize > 640) {
            options.inSampleSize *= 2
        }
        val source = BitmapFactory.decodeFile(path, options) ?: return null
        try {
            val orientation = ExifInterface(path).getAttributeInt(
                ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
            val matrix = Matrix().apply {
                when (orientation) {
                    ExifInterface.ORIENTATION_ROTATE_90 -> postRotate(90f)
                    ExifInterface.ORIENTATION_ROTATE_180 -> postRotate(180f)
                    ExifInterface.ORIENTATION_ROTATE_270 -> postRotate(270f)
                    ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> postScale(-1f, 1f)
                    ExifInterface.ORIENTATION_FLIP_VERTICAL -> postScale(1f, -1f)
                    ExifInterface.ORIENTATION_TRANSPOSE -> { postRotate(90f); postScale(-1f, 1f) }
                    ExifInterface.ORIENTATION_TRANSVERSE -> { postRotate(270f); postScale(-1f, 1f) }
                }
            }
            val upright = Bitmap.createBitmap(source, 0, 0, source.width, source.height, matrix, true)
            try {
                // Android FaceDetector requires RGB_565 and an even width.
                val even = Bitmap.createBitmap(upright, 0, 0,
                    upright.width - upright.width % 2, upright.height)
                try {
                    val bitmap = even.copy(Bitmap.Config.RGB_565, false) ?: return null
                    try {
                        val faces = arrayOfNulls<FaceDetector.Face>(3)
                        FaceDetector(bitmap.width, bitmap.height, 3).findFaces(bitmap, faces)
                        val face = faces.filterNotNull().filter { it.confidence() >= 0.4f }
                            .maxByOrNull { it.eyesDistance() }
                        val center = PointF()
                        face?.getMidPoint(center)
                        val half = (face?.eyesDistance() ?: 0f) * 1.4f
                        val left = if (face == null) 0 else (center.x - half).toInt().coerceIn(0, bitmap.width - 1)
                        val right = if (face == null) bitmap.width else (center.x + half).toInt().coerceIn(left + 1, bitmap.width)
                        val top = if (face == null) 0 else (center.y - half).toInt().coerceIn(0, bitmap.height - 1)
                        val bottom = if (face == null) bitmap.height else (center.y + half).toInt().coerceIn(top + 1, bitmap.height)
                        var luminance = 0.0
                        var count = 0
                        for (y in top until bottom step 4) for (x in left until right step 4) {
                            val pixel = bitmap.getPixel(x, y)
                            luminance += 0.2126 * ((pixel shr 16) and 255) +
                                0.7152 * ((pixel shr 8) and 255) + 0.0722 * (pixel and 255)
                            count++
                        }
                        return mapOf("brightness" to luminance / count,
                            "faceWidth" to face?.let { (it.eyesDistance() * 2.8 / bitmap.width).toDouble() })
                    } finally { bitmap.recycle() }
                } finally { if (even !== upright) even.recycle() }
            } finally { if (upright !== source) upright.recycle() }
        } finally { source.recycle() }
    }

    override fun onDestroy() {
        cameraWorker.shutdown()
        super.onDestroy()
    }
}
