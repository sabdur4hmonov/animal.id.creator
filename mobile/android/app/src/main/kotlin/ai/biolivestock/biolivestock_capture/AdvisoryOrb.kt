package ai.biolivestock.biolivestock_capture

import android.content.Context
import android.os.SystemClock
import org.json.JSONArray
import org.json.JSONObject
import org.opencv.android.OpenCVLoader
import org.opencv.calib3d.Calib3d
import org.opencv.core.*
import org.opencv.features2d.BFMatcher
import org.opencv.features2d.ORB
import org.opencv.imgcodecs.Imgcodecs
import org.opencv.imgproc.Imgproc
import java.io.*
import java.security.MessageDigest
import kotlin.math.*

/** Human-review candidates only. The matcher never allocates, selects, or merges IDs. */
class AdvisoryOrb(private val context: Context, private val rules: JSONObject, private val rulesHash: String) {
    private val cache = File(context.cacheDir, "orb-4.13-v1").apply { mkdirs() }
    private val root = File(context.applicationInfo.dataDir).canonicalFile.toPath()
    private val limit = rules.getInt("feature_limit")
    private val hex = Regex("[a-f0-9]{64}")
    private var cacheHits = 0
    private var extracted = 0
    private data class Features(val xy: Array<Point>, val bytes: ByteArray) {
        fun mat() = Mat(xy.size, 32, CvType.CV_8UC1).apply { if (bytes.isNotEmpty()) put(0, 0, bytes) }
    }

    init {
        require(hex.matches(rulesHash) && limit in 64..2048)
        check(OpenCVLoader.initLocal()) { "OpenCV unavailable" }
    }

    private fun ownImage(path: String): File {
        val file = File(path).canonicalFile
        require(file.toPath().startsWith(root) && file.isFile)
        return file
    }

    private fun extract(file: File, orb: ORB): Features {
        val gray = Imgcodecs.imread(file.path, Imgcodecs.IMREAD_REDUCED_GRAYSCALE_2)
        val resized = Mat(); val descriptors = Mat(); val keypoints = MatOfKeyPoint(); val mask = Mat()
        var cropped: Mat? = null
        try {
            require(!gray.empty()) { "Unreadable image" }
            val fraction = rules.getDouble("center_crop_fraction")
            require(fraction in 0.25..1.0)
            val w = (gray.cols() * fraction).roundToInt().coerceAtLeast(1)
            val h = (gray.rows() * fraction).roundToInt().coerceAtLeast(1)
            cropped = gray.submat(Rect((gray.cols()-w)/2,(gray.rows()-h)/2,w,h))
            val scale = min(1.0, rules.getInt("max_image_side").toDouble()/max(w,h))
            Imgproc.resize(cropped,resized,Size(max(1.0,round(w*scale)),max(1.0,round(h*scale))),0.0,0.0,Imgproc.INTER_AREA)
            orb.detectAndCompute(resized,mask,keypoints,descriptors)
            val xy=keypoints.toArray().map { it.pt }.toTypedArray()
            val bytes=ByteArray(xy.size*32)
            if(bytes.isNotEmpty()) {
                check(descriptors.cols()==32 && descriptors.rows()==xy.size && xy.size<=limit)
                descriptors.get(0,0,bytes)
            }
            return Features(xy,bytes)
        } finally {
            cropped?.release();gray.release();resized.release();descriptors.release();keypoints.release();mask.release()
        }
    }

    private fun features(path: String, sha: String, orb: ORB): Features {
        require(hex.matches(sha))
        val photo=ownImage(path)
        val cached=File(cache,"$rulesHash-$sha.bin")
        if(cached.isFile) {
            try {
                DataInputStream(BufferedInputStream(cached.inputStream())).use { input ->
                    val count=input.readInt()
                    require(count in 0..limit && cached.length()==4L+count*40L)
                    val xy=Array(count) { Point(input.readFloat().toDouble(),input.readFloat().toDouble()) }
                    require(xy.all { it.x.isFinite() && it.y.isFinite() })
                    val bytes=ByteArray(count*32);input.readFully(bytes)
                    cacheHits++
                    return Features(xy,bytes)
                }
            } catch (_: Exception) { /* A derived cache may be rebuilt, never the original. */ }
        }
        require(fileHash(photo)==sha) { "Original checksum mismatch" }
        val result=extract(photo,orb);extracted++
        val tmp=File.createTempFile("orb-", ".next",cache)
        try {
            DataOutputStream(BufferedOutputStream(tmp.outputStream())).use { out ->
                out.writeInt(result.xy.size)
                result.xy.forEach { out.writeFloat(it.x.toFloat());out.writeFloat(it.y.toFloat()) }
                out.write(result.bytes)
            }
            if(!tmp.renameTo(cached)) throw IOException("Descriptor cache publish failed")
        } finally { if(tmp.exists())tmp.delete() }
        return result
    }

    private fun geometry(q: Features, query: Mat, r: Features, matcher: BFMatcher): Pair<Int,Int> {
        if(q.xy.size<4 || r.xy.size<4)return 0 to 0
        val reference=r.mat();val neighbors=mutableListOf<MatOfDMatch>()
        val src=MatOfPoint2f();val dst=MatOfPoint2f();val mask=Mat()
        var transform: Mat?=null
        try {
            matcher.knnMatch(query,reference,neighbors,2)
            val selected=HashMap<Int,DMatch>();val ratio=rules.getDouble("lowe_ratio")
            for(group in neighbors) {
                val pair=group.toArray()
                if(pair.size!=2 || pair[0].distance>=ratio*pair[1].distance)continue
                val m=pair[0]
                if(selected[m.trainIdx]?.let { it.distance<=m.distance } != true)selected[m.trainIdx]=m
            }
            val matches=selected.values.sortedBy { it.queryIdx }
            // Below the configured inlier count even perfect geometry cannot warn.
            if(matches.size<rules.getInt("min_inliers"))return 0 to matches.size
            src.fromList(matches.map { q.xy[it.queryIdx] });dst.fromList(matches.map { r.xy[it.trainIdx] })
            transform=Calib3d.findHomography(src,dst,Calib3d.RANSAC,rules.getDouble("ransac_reprojection_px"),mask,
                rules.getInt("ransac_iterations"),rules.getDouble("ransac_confidence"))
            return (if(transform.empty() || mask.empty())0 else Core.countNonZero(mask)) to matches.size
        } finally {
            neighbors.forEach { it.release() };reference.release();src.release();dst.release();mask.release();transform?.release()
        }
    }

    fun compare(request: JSONObject): JSONObject {
        val start=SystemClock.elapsedRealtimeNanos()
        val orb=ORB.create(limit,rules.getDouble("pyramid_scale").toFloat(),rules.getInt("pyramid_levels"),rules.getInt("edge_threshold"),0,2,ORB.HARRIS_SCORE,rules.getInt("patch_size"),rules.getInt("fast_threshold"))
        val matcher=BFMatcher.create(Core.NORM_HAMMING,false)
        val q=features(request.getString("query_path"),request.getString("query_sha256"),orb)
        val query=q.mat()
        val best=HashMap<String,JSONObject>();var failures=0;var compared=0
        val order=compareByDescending<JSONObject> { it.getBoolean("warning") }.thenByDescending { it.getDouble("score") }.thenBy { it.getString("animal_id") }.thenBy { it.getString("photo_key") }
        try {
            val refs=request.getJSONArray("references")
            for(i in 0 until refs.length()) {
                val item=refs.getJSONObject(i)
                try {
                    val r=features(item.getString("path"),item.getString("sha256"),orb)
                    val (inliers,matches)=geometry(q,query,r,matcher);compared++
                    val ratio=if(matches==0)0.0 else inliers.toDouble()/matches
                    val label=item.getString("animal_id")
                    val candidate=JSONObject().put("animal_id",label).put("photo_key",item.getString("photo_key"))
                        .put("inliers",inliers).put("matches",matches).put("inlier_ratio",ratio).put("score",inliers*ratio)
                        .put("geometry_checked",matches>=rules.getInt("min_inliers"))
                        .put("warning",inliers>=rules.getInt("min_inliers") && ratio>=rules.getDouble("min_inlier_ratio"))
                    if(best[label]?.let { order.compare(candidate,it)<0 } != false)best[label]=candidate
                } catch (_: Exception) { failures++ }
            }
            return JSONObject().put("candidates",JSONArray(best.values.sortedWith(order).take(rules.getInt("top_k"))))
                .put("compared_photos",compared).put("failed_photos",failures).put("query_features",q.xy.size)
                .put("cache_hits",cacheHits).put("extracted",extracted).put("elapsed_ms",(SystemClock.elapsedRealtimeNanos()-start)/1e6)
                .put("engine","opencv_orb_4.13.0_lowe_ransac_v1").put("calibrated",false)
        } finally { query.release();matcher.clear();orb.clear() }
    }

    companion object {
        fun fileHash(file: File): String {
            val digest=MessageDigest.getInstance("SHA-256")
            file.inputStream().buffered().use { input ->
                val buffer=ByteArray(65536)
                while(true){val n=input.read(buffer);if(n<0)break;digest.update(buffer,0,n)}
            }
            return digest.digest().joinToString(""){"%02x".format(it)}
        }
    }
}
