package ai.biolivestock.biolivestock_capture

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.view.View

/** Original schematic, with readable numbers on both mirrored sides. */
class PointGuideView(context:Context):View(context){
    var step=0;var right=false;var front=false;var contour=false
    private val paint=Paint(Paint.ANTI_ALIAS_FLAG)
    override fun onDraw(canvas:Canvas){
        super.onDraw(canvas)
        val sx=width/300f;val sy=height/120f;canvas.save();canvas.scale(sx,sy)
        fun x(value:Float)=if(right)300-value else value
        paint.color=0xffa77956.toInt();paint.style=Paint.Style.FILL
        if(front){canvas.drawRoundRect(105f,20f,195f,110f,30f,30f,paint)}
        else{
            canvas.drawRoundRect(if(right)40f else 65f,20f,if(right)235f else 260f,90f,22f,22f,paint)
            canvas.drawOval(if(right)250f else 2f,38f,if(right)298f else 50f,76f,paint)
            val neck=Path().apply{moveTo(x(30f),40f);lineTo(x(80f),30f);lineTo(x(95f),75f);lineTo(x(25f),77f);close()};canvas.drawPath(neck,paint)
            for(px in listOf(100f,120f,225f,245f))canvas.drawRect(x(px)-4,80f,x(px)+4,115f,paint)
        }
        val positions=if(contour)(0..7).map { val angle=it*Math.PI/4;150f+45f*kotlin.math.sin(angle).toFloat() to 65f-45f*kotlin.math.cos(angle).toFloat() } else if(front)listOf(105f to 60f,195f to 60f) else listOf(x(70f) to 55f,x(255f) to 48f,x(105f) to 20f,x(105f) to 88f)
        positions.forEachIndexed{i,p->
            paint.color=if(i==step)0xffffce40.toInt() else 0xffdce7e2.toInt();canvas.drawCircle(p.first,p.second,if(i==step)11f else 8f,paint)
            paint.color=0xff142d24.toInt();paint.textSize=12f;paint.textAlign=Paint.Align.CENTER;canvas.drawText("${i+1}",p.first,p.second+4,paint)
        };canvas.restore()
    }
}
