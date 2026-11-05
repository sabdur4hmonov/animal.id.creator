package ai.biolivestock.biolivestock_capture

import android.graphics.Bitmap
import android.opengl.GLES20
import android.util.Base64
import com.google.ar.core.Frame
import com.google.ar.core.Coordinates2d
import com.google.ar.core.TrackingState
import org.json.JSONArray
import org.json.JSONObject
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.io.ByteArrayOutputStream
import java.security.MessageDigest
import java.util.UUID
import kotlin.math.*

/** Copies every buffer before releasing the AR images. Never reprojects an older depth frame. */
object FrozenDepth {
    private fun encoded(bytes:ByteArray)=Base64.encodeToString(bytes,Base64.NO_WRAP)
    private fun hash(bytes:ByteArray)=MessageDigest.getInstance("SHA-256").digest(bytes).joinToString(""){"%02x".format(it)}
    private fun floats(a:FloatArray)=ByteBuffer.allocateDirect(a.size*4).order(ByteOrder.nativeOrder()).asFloatBuffer().apply{put(a);position(0)}
    fun capture(frame:Frame,width:Int,height:Int,rules:JSONObject):JSONObject {
        check(frame.camera.trackingState==TrackingState.TRACKING)
        frame.acquireRawDepthImage16Bits().use { depth ->
            frame.acquireRawDepthConfidenceImage().use { confidence ->
                // A stale/reprojected raw depth image is not the requested camera instant.
                check(depth.timestamp==frame.timestamp && confidence.timestamp==frame.timestamp)
                val w=depth.width;val h=depth.height
                check(w==confidence.width&&h==confidence.height&&w*h<=rules.getInt("snapshot_max_depth_pixels"))
                val d=ByteBuffer.allocate(w*h*2).order(ByteOrder.LITTLE_ENDIAN);val c=ByteArray(w*h)
                val dp=depth.planes[0];val cp=confidence.planes[0]
                val db=dp.buffer.duplicate().order(ByteOrder.LITTLE_ENDIAN);val cb=cp.buffer.duplicate()
                for(y in 0 until h)for(x in 0 until w){d.putShort(db.getShort(y*dp.rowStride+x*dp.pixelStride));c[y*w+x]=cb.get(y*cp.rowStride+x*cp.pixelStride)}
                val k=frame.camera.imageIntrinsics;val focal=k.focalLength;val principal=k.principalPoint;val size=k.imageDimensions
                val pose=FloatArray(16);frame.camera.pose.toMatrix(pose,0)
                val input=floats(floatArrayOf(0f,0f,width.toFloat(),0f,0f,height.toFloat()));val output=floats(FloatArray(6))
                frame.transformCoordinates2d(Coordinates2d.VIEW,input,Coordinates2d.IMAGE_NORMALIZED,output)
                val pixels=ByteBuffer.allocateDirect(width*height*4).order(ByteOrder.nativeOrder())
                GLES20.glReadPixels(0,0,width,height,GLES20.GL_RGBA,GLES20.GL_UNSIGNED_BYTE,pixels)
                check(GLES20.glGetError()==GLES20.GL_NO_ERROR)
                // Public ARGB color integers avoid native bitmap channel-order assumptions.
                val colors=IntArray(width*height)
                for(y in 0 until height)for(x in 0 until width){
                    val i=(y*width+x)*4;val r=pixels.get(i).toInt() and 255;val g=pixels.get(i+1).toInt() and 255;val b=pixels.get(i+2).toInt() and 255
                    colors[(height-1-y)*width+x]=(255 shl 24) or (r shl 16) or (g shl 8) or b
                }
                val flipped=Bitmap.createBitmap(colors,width,height,Bitmap.Config.ARGB_8888)
                val ratio=min(1.0,960.0/max(width,height));val small=Bitmap.createScaledBitmap(flipped,(width*ratio).toInt().coerceAtLeast(1),(height*ratio).toInt().coerceAtLeast(1),true)
                val stream=ByteArrayOutputStream();small.compress(Bitmap.CompressFormat.JPEG,85,stream)
                val jpeg=stream.toByteArray();if(small!==flipped)small.recycle();flipped.recycle()
                val result=JSONObject().put("measurement_source","arcore_frozen_raw_depth").put("frame_id",UUID.randomUUID().toString())
                    .put("camera_timestamp_ns",frame.timestamp.toString()).put("depth_timestamp_ns",depth.timestamp.toString()).put("confidence_timestamp_ns",confidence.timestamp.toString())
                    .put("camera_capture_utc",java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",java.util.Locale.US).apply{timeZone=java.util.TimeZone.getTimeZone("UTC")}.format(java.util.Date()))
                    .put("tracking","TRACKING").put("units","m").put("depth_width",w).put("depth_height",h).put("view_width",width).put("view_height",height)
                    .put("camera_pose_column_major",JSONArray(pose.map{it.toDouble()})).put("view_to_image_normalized",JSONArray((0..5).map{output[it].toDouble()}))
                    .put("image_intrinsics",JSONObject().put("fx",focal[0].toDouble()).put("fy",focal[1].toDouble()).put("cx",principal[0].toDouble()).put("cy",principal[1].toDouble()).put("width",size[0]).put("height",size[1]))
                    .put("depth_intrinsics",JSONObject().put("fx",focal[0].toDouble()*w/size[0]).put("fy",focal[1].toDouble()*h/size[1]).put("cx",principal[0].toDouble()*w/size[0]).put("cy",principal[1].toDouble()*h/size[1]))
                    .put("depth_u16le_base64",encoded(d.array())).put("confidence_u8_base64",encoded(c)).put("jpeg_base64",encoded(jpeg))
                    .put("depth_sha256",hash(d.array())).put("confidence_sha256",hash(c)).put("jpeg_sha256",hash(jpeg)).put("motion_assessed",false)
                return result
            }
        }
    }
}
