package ai.biolivestock.biolivestock_capture

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.os.Bundle
import android.util.Base64
import android.view.MotionEvent
import android.widget.*
import com.google.ar.core.*
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import kotlin.math.*

/** Original minimal local renderer using official ARCore APIs; no unlicensed renderer is imported. */
class ArMeasureActivity : Activity(), GLSurfaceView.Renderer {
    private lateinit var surface: GLSurfaceView
    private lateinit var label: TextView
    private lateinit var spec: JSONObject
    private var session: Session? = null
    private var texture = 0
    private var program = 0
    private var markerProgram = 0
    private var width = 1
    private var height = 1
    private var tap: Pair<Float, Float>? = null
    private var depth = false
    @Volatile private var closing = false
    private var began = 0L
    private val points = JSONArray()
    private val anchors = mutableListOf<Anchor>()
    private val initialAnchors = mutableListOf<FloatArray>()
    private val screenshots = JSONArray()
    private val screenshotFrames = JSONArray()
    private val tracking = JSONArray()
    private var trackingState = ""
    private var scaleCheck: JSONObject? = null
    private val reference = mutableListOf<FloatArray>()
    private val referenceEvidence = JSONArray()
    private var finishRequested = false
    private fun text(key: String) = spec.getJSONObject("labels").optString(key, key)
    private fun rule(key: String) = spec.getJSONObject("rules").getDouble(key)
    private fun vector(pose: Pose) = floatArrayOf(pose.tx(), pose.ty(), pose.tz())
    private fun distance(a: FloatArray, b: FloatArray) = sqrt(a.indices.sumOf { (a[it]-b[it]).toDouble().pow(2) })
    private fun hint(message: String) = runOnUiThread { if (!closing) label.text = message }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            spec = JSONObject(intent.getStringExtra("spec")!!)
            if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                fail("camera_permission_required"); return
            }
            val availability = ArCoreApk.getInstance().checkAvailability(this)
            if (availability != ArCoreApk.Availability.SUPPORTED_INSTALLED) {
                fail(if (availability.isUnsupported) "unsupported" else "ar_services_required_or_unknown"); return
            }
            session = Session(this)
            depth = session!!.isDepthModeSupported(Config.DepthMode.AUTOMATIC)
            session!!.configure(Config(session).apply {
                depthMode = if (depth) Config.DepthMode.AUTOMATIC else Config.DepthMode.DISABLED
                planeFindingMode = Config.PlaneFindingMode.DISABLED
                updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
            })
            val layout = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setBackgroundColor(0xff183f32.toInt()) }
            val scroll = ScrollView(this)
            label = TextView(this).apply { textSize = 17f; setTextColor(-1); setPadding(14, 10, 14, 10); text = text("safety") }
            label.text="${text("safety")}\n${if(spec.optDouble("reference_cm",0.0)>0)text("reference") else text("bodyStart")}"
            scroll.addView(label); layout.addView(scroll, LinearLayout.LayoutParams(-1, (170*resources.displayMetrics.density).toInt()))
            surface = GLSurfaceView(this).apply {
                setEGLContextClientVersion(2); preserveEGLContextOnPause = true; setRenderer(this@ArMeasureActivity)
                setOnTouchListener { _, event -> if (event.action == MotionEvent.ACTION_UP) { val x=event.x;val y=event.y;queueEvent { tap = Pair(x, y) }; performClick() }; true }
            }
            layout.addView(surface, LinearLayout.LayoutParams(-1, 0, 1f))
            val actions = LinearLayout(this)
            actions.addView(Button(this).apply { setText(text("cancel")); setOnClickListener { fail("cancelled") } }, LinearLayout.LayoutParams(0, -2, 1f))
            actions.addView(Button(this).apply { setText(text("finish")); setOnClickListener { surface.queueEvent { finishRequested = true } } }, LinearLayout.LayoutParams(0, -2, 1f))
            layout.addView(actions); setContentView(layout)
            began = System.nanoTime()
        } catch (e: Exception) { fail("session_unavailable:${e.javaClass.simpleName}") }
    }

    override fun onResume() {
        super.onResume()
        if (session == null || closing) return
        try { session!!.resume(); surface.onResume() } catch (e: Exception) { fail("camera_or_session_unavailable") }
    }
    override fun onPause() {
        if (::surface.isInitialized) surface.onPause()
        session?.pause()
        super.onPause()
        // A world map cannot safely continue after interruption or lock screen.
        if (!closing) fail("measurement_interrupted")
    }
    override fun onDestroy() { anchors.forEach { it.detach() }; session?.close(); session = null; super.onDestroy() }
    @Deprecated("Activity back callback")
    override fun onBackPressed() { fail("cancelled") }
    private fun fail(reason: String) {
        if (closing) return
        closing = true
        val partial=JSONObject().put("mode",if(::spec.isInitialized)spec.optString("mode") else "unknown")
            .put("points",points).put("tracking_history",tracking).put("screenshots_jpeg_base64",screenshots).put("duration_seconds",(System.nanoTime()-began)/1e9)
        scaleCheck?.let{partial.put("scale_check",it)}
        val file=java.io.File.createTempFile("ar-result-",".json",cacheDir);file.writeText(partial.toString())
        setResult(RESULT_CANCELED, Intent().putExtra("error", reason).putExtra("measurement_file",file.absolutePath)); finish()
    }
    private fun shader(type: Int, source: String): Int {
        val id = GLES20.glCreateShader(type); GLES20.glShaderSource(id, source); GLES20.glCompileShader(id)
        val compiled = IntArray(1); GLES20.glGetShaderiv(id, GLES20.GL_COMPILE_STATUS, compiled, 0)
        check(compiled[0] != 0) { "Shader failed" }; return id
    }
    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        try {
            val names = IntArray(1); GLES20.glGenTextures(1, names, 0); texture = names[0]
            GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, texture)
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
            val vertex = shader(GLES20.GL_VERTEX_SHADER, "attribute vec2 p; attribute vec2 uv; varying vec2 v; void main(){gl_Position=vec4(p,0.,1.);v=uv;}")
            val fragment = shader(GLES20.GL_FRAGMENT_SHADER, "#extension GL_OES_EGL_image_external : require\nprecision mediump float; uniform samplerExternalOES camera; varying vec2 v; void main(){gl_FragColor=texture2D(camera,v);}")
            program = GLES20.glCreateProgram(); GLES20.glAttachShader(program, vertex); GLES20.glAttachShader(program, fragment); GLES20.glLinkProgram(program)
            val linked=IntArray(1);GLES20.glGetProgramiv(program,GLES20.GL_LINK_STATUS,linked,0);check(linked[0]!=0)
            val markerVertex=shader(GLES20.GL_VERTEX_SHADER,"attribute vec3 p; uniform mat4 vp; void main(){gl_Position=vp*vec4(p,1.);gl_PointSize=18.;}")
            val markerFragment=shader(GLES20.GL_FRAGMENT_SHADER,"precision mediump float; void main(){gl_FragColor=vec4(0.2,1.,0.7,1.);}")
            markerProgram=GLES20.glCreateProgram();GLES20.glAttachShader(markerProgram,markerVertex);GLES20.glAttachShader(markerProgram,markerFragment);GLES20.glLinkProgram(markerProgram)
            GLES20.glGetProgramiv(markerProgram,GLES20.GL_LINK_STATUS,linked,0);check(linked[0]!=0)
            session?.setCameraTextureName(texture)
        } catch(e: Exception) { runOnUiThread { fail("renderer_unavailable") } }
    }
    override fun onSurfaceChanged(gl: GL10?, w: Int, h: Int) {
        width=w; height=h; GLES20.glViewport(0,0,w,h)
        @Suppress("DEPRECATION")
        session?.setDisplayGeometry(windowManager.defaultDisplay.rotation,w,h)
    }
    private fun floats(values: FloatArray) = ByteBuffer.allocateDirect(values.size*4).order(ByteOrder.nativeOrder()).asFloatBuffer().apply { put(values); position(0) }
    override fun onDrawFrame(gl: GL10?) {
        val current = session ?: return
        if (closing) return
        try {
            val frame=current.update(); val camera=frame.camera
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
            if(frame.timestamp==0L)return
            val vertices=floats(floatArrayOf(-1f,-1f,1f,-1f,-1f,1f,1f,1f));val uvs=floats(FloatArray(8))
            frame.transformCoordinates2d(Coordinates2d.OPENGL_NORMALIZED_DEVICE_COORDINATES, vertices, Coordinates2d.TEXTURE_NORMALIZED, uvs)
            vertices.position(0);uvs.position(0)
            GLES20.glUseProgram(program); GLES20.glActiveTexture(GLES20.GL_TEXTURE0);GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES,texture)
            GLES20.glUniform1i(GLES20.glGetUniformLocation(program,"camera"),0)
            val p=GLES20.glGetAttribLocation(program,"p");val uv=GLES20.glGetAttribLocation(program,"uv")
            GLES20.glEnableVertexAttribArray(p);GLES20.glEnableVertexAttribArray(uv)
            GLES20.glVertexAttribPointer(p,2,GLES20.GL_FLOAT,false,0,vertices);GLES20.glVertexAttribPointer(uv,2,GLES20.GL_FLOAT,false,0,uvs)
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP,0,4)
            drawMarkers(frame)
            val state=camera.trackingState.name
            if(state!=trackingState){tracking.put(JSONObject().put("state",state).put("reason",camera.trackingFailureReason.name).put("frame_ns",frame.timestamp));trackingState=state}
            if(camera.trackingState!=TrackingState.TRACKING){
                if(points.length()>0 || reference.isNotEmpty()){runOnUiThread{fail("tracking_lost_repeat_measurement")};return}
                hint(text("tracking"));tap=null;return
            }
            if((System.nanoTime()-began)/1e9>rule("max_session_seconds")){runOnUiThread{fail("measurement_timed_out")};return}
            if(anchors.indices.any { anchors[it].trackingState!=TrackingState.TRACKING || distance(vector(anchors[it].pose),initialAnchors[it])>rule("max_anchor_drift_m") }){
                runOnUiThread{fail("anchor_changed_repeat_measurement")};return
            }
            val selected=tap;tap=null
            if(selected!=null)capturePoint(frame,selected.first,selected.second)
            if(finishRequested){finishRequested=false;complete(frame)}
        } catch(e: Exception){ hint(text("tracking")) }
    }
    private fun drawMarkers(frame:Frame){
        if(initialAnchors.isEmpty())return
        val projection=FloatArray(16);val view=FloatArray(16);val vp=FloatArray(16)
        frame.camera.getProjectionMatrix(projection,0,.05f,100f);frame.camera.getViewMatrix(view,0)
        android.opengl.Matrix.multiplyMM(vp,0,projection,0,view,0)
        GLES20.glUseProgram(markerProgram);GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(markerProgram,"vp"),1,false,vp,0)
        val attribute=GLES20.glGetAttribLocation(markerProgram,"p");GLES20.glEnableVertexAttribArray(attribute)
        val data=floats(initialAnchors.flatMap{it.toList()}.toFloatArray())
        GLES20.glVertexAttribPointer(attribute,3,GLES20.GL_FLOAT,false,0,data);GLES20.glDrawArrays(GLES20.GL_POINTS,0,initialAnchors.size)
    }
    private fun confidence(frame: Frame, hit: HitResult, x: Float, y: Float): Double? {
        if(hit.trackable is DepthPoint && depth){
            try {
                val input=floats(floatArrayOf(x,y));val normalized=floats(FloatArray(2))
                frame.transformCoordinates2d(Coordinates2d.VIEW,input,Coordinates2d.IMAGE_NORMALIZED,normalized)
                frame.acquireRawDepthConfidenceImage().use { image ->
                    frame.acquireRawDepthImage16Bits().use { raw ->
                        if(image.timestamp!=raw.timestamp || image.width!=raw.width || image.height!=raw.height || abs(frame.timestamp-raw.timestamp)>rule("max_depth_age_ms")*1000000)return null
                        if(normalized[0]<0 || normalized[0]>=1 || normalized[1]<0 || normalized[1]>=1)return null
                        val px=(normalized[0]*image.width).toInt().coerceIn(0,image.width-1);val py=(normalized[1]*image.height).toInt().coerceIn(0,image.height-1)
                        val plane=image.planes[0];val score=(plane.buffer.get(py*plane.rowStride+px*plane.pixelStride).toInt() and 255)/255.0
                        val rp=raw.planes[0]; val millimeters=rp.buffer.order(ByteOrder.nativeOrder()).getShort(py*rp.rowStride+px*rp.pixelStride).toInt() and 65535
                        if(millimeters==0)return null
                        // Compare camera-Z depth rather than Euclidean hit range.
                        val z=-frame.camera.pose.inverse().compose(hit.hitPose).tz()
                        if(abs(millimeters/1000.0-z)>rule("max_point_distance_m"))return null
                        return score
                    }
                }
            } catch(e: Exception){return null}
        }
        if(!depth && hit.trackable is Point){
            frame.acquirePointCloud().use { cloud ->
                if(abs(frame.timestamp-cloud.timestamp)>rule("max_depth_age_ms")*1000000)return null
                val values=cloud.points;val target=vector(hit.hitPose);var best=rule("max_point_distance_m");var score:Double?=null
                var i=0;while(i+3<values.limit()){
                    val d=distance(target,floatArrayOf(values[i],values[i+1],values[i+2]))
                    if(d<best){best=d;score=values[i+3].toDouble()};i+=4
                };return score
            }
        }
        return null
    }
    private fun capturePoint(frame: Frame,x:Float,y:Float){
        val required=if(spec.getString("mode")=="fast")6 else 2+rule("max_contour_points").toInt()
        if(points.length()>=required){hint(text("finish"));return}
        val candidate=frame.hitTest(x,y).firstOrNull { it.trackable.trackingState==TrackingState.TRACKING && (if(depth)it.trackable is DepthPoint else it.trackable is Point) && (confidence(frame,it,x,y)?:-1.0)>=rule("min_point_confidence") }
        if(candidate==null){hint(text("lowConfidence"));return}
        val score=confidence(frame,candidate,x,y)?:return;val xyz=vector(candidate.hitPose)
        val referenceCm=spec.optDouble("reference_cm",0.0)
        val anchor=candidate.createAnchor();anchors.add(anchor);initialAnchors.add(xyz)
        if(referenceCm>0 && reference.size<2){
            reference.add(xyz)
            referenceEvidence.put(JSONObject().put("x",xyz[0].toDouble()).put("y",xyz[1].toDouble()).put("z",xyz[2].toDouble()).put("confidence",score).put("tracking","TRACKING").put("frame_ns",frame.timestamp))
            if(reference.size==2){val measured=distance(reference[0],reference[1])*100
                scaleCheck=JSONObject().put("expected_cm",referenceCm).put("measured_cm",measured).put("error_pct",abs(measured-referenceCm)/referenceCm*100).put("points",referenceEvidence).put("source","user_selected_known_object")
                if(abs(measured-referenceCm)/referenceCm*100>rule("max_scale_check_error_pct")){runOnUiThread{fail("scale_check_failed")};return}
            }
        }else{
            points.put(JSONObject().put("x",xyz[0].toDouble()).put("y",xyz[1].toDouble()).put("z",xyz[2].toDouble()).put("confidence",score).put("tracking","TRACKING").put("frame_ns",frame.timestamp).put("hit_type",if(depth)"DepthPoint" else "PointCloudPoint").put("screen_x",x).put("screen_y",y))
            if(points.length()==2)screenshot(frame.timestamp)
        }
        val step=if(referenceCm>0 && reference.size<2) text("reference") else when(points.length()){
            0->text("bodyStart");1->text("bodyEnd");2->if(spec.getString("mode")=="fast")text("depthTop") else text("contour")
            3->if(spec.getString("mode")=="fast")text("depthBottom") else text("contour")
            4->if(spec.getString("mode")=="fast")text("widthLeft") else text("contour")
            5->if(spec.getString("mode")=="fast")text("widthRight") else text("contour")
            else->if(spec.getString("mode")=="fast")text("finish") else text("contour") }
        hint("${text("safety")}\n${points.length()}: $step")
    }
    private fun screenshot(frameTimestamp:Long){
        if(screenshots.length()>=2)return
        val pixels=ByteBuffer.allocateDirect(width*height*4).order(ByteOrder.nativeOrder());GLES20.glReadPixels(0,0,width,height,GLES20.GL_RGBA,GLES20.GL_UNSIGNED_BYTE,pixels)
        val raw=Bitmap.createBitmap(width,height,Bitmap.Config.ARGB_8888);pixels.rewind();raw.copyPixelsFromBuffer(pixels)
        val matrix=android.graphics.Matrix().apply { preScale(1f,-1f) };val bitmap=Bitmap.createBitmap(raw,0,0,width,height,matrix,false)
        val ratio=min(1.0,960.0/max(width,height));val small=Bitmap.createScaledBitmap(bitmap,(width*ratio).toInt().coerceAtLeast(1),(height*ratio).toInt().coerceAtLeast(1),true)
        val stream=ByteArrayOutputStream();small.compress(Bitmap.CompressFormat.JPEG,70,stream);screenshots.put(Base64.encodeToString(stream.toByteArray(),Base64.NO_WRAP));if(small!==bitmap)small.recycle();bitmap.recycle();raw.recycle()
        screenshotFrames.put(JSONObject().put("frame_ns",frameTimestamp).put("point_count",points.length()).put("tracking",trackingState))
    }
    private fun complete(frame: Frame){
        val fast=spec.getString("mode")=="fast"
        if(fast && points.length()!=6 || !fast && points.length()<2+rule("min_contour_points").toInt()) {hint(text("morePoints"));return}
        screenshot(frame.timestamp)
        val result=JSONObject().put("measurement_source","arcore_metric").put("units","m").put("mode",spec.getString("mode")).put("points",points)
            .put("depth_supported",depth).put("tracking_history",tracking).put("duration_seconds",(System.nanoTime()-began)/1e9)
            .put("screenshots_jpeg_base64",screenshots).put("screenshot_frames",screenshotFrames).put("camera_timestamp_ns",frame.timestamp).put("motion_assessed",false)
        scaleCheck?.let { result.put("scale_check",it) }
        // Images must not cross Android Binder's transaction size limit.
        val file=java.io.File.createTempFile("ar-result-",".json",cacheDir)
        file.writeText(result.toString())
        runOnUiThread {if(!closing){closing=true;setResult(RESULT_OK,Intent().putExtra("measurement_file",file.absolutePath));finish()}}
    }
}
