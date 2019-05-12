Shader "aivo/Liquish"
{
	//implementation stole from vvvv. because its a nice shader
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_ColorA("ColorA", Color) = (0,1,1,1)
		_ColorB("ColorB", Color) = (1,0,1,1)
		_ColorC("ColorC", Color) = (1,1,0,1)
		_Scale("Scale", Range(0.01,10.0)) = 0.7
		_TimeFactor("Time Factor", Range(0.01,5.15)) = 1

    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment pLiquish

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };
	
			sampler2D _MainTex;
			float4 _ColorA;
			float4 _ColorB;
			float4 _ColorC;
			float _Scale;
			float _TimeFactor;


			//helper functions
			float rand(float2 co) {
				// implementation found at: lumina.sourceforge.net/Tutorials/Noise.html
				return frac(sin(dot(co.xy, float2(12.9898, 78.233))) * 43758.5453);
			}

			float noise2f(in float2 p)
			{
				float2 ip = float2(floor(p));
				float2 u = frac(p);
				// http://www.iquilezles.org/www/articles/morenoise/morenoise.htm
				u = u * u*(3.0 - 2.0*u);
				float res = lerp(
					lerp(rand(ip), rand(ip + float2(1.0, 0.0)), u.x),
					lerp(rand(ip + float2(0.0, 1.0)), rand(ip + float2(1.0, 1.0)), u.x),
					u.y);
				return res * res;
			}

			float fbm(float2 c) {
				float f = 0.0;
				float w = 1.0;
				for (int i = 0; i < 4; i++) {
					f += w * noise2f(c);
					c *= 2.0;
					w *= 0.5;
				}
				return f;
			}

			float2 cMul(float2 a, float2 b) {
				return float2(a.x*b.x - a.y*b.y, a.x*b.y + a.y * b.x);
			}

			float pattern(float2 p, out float2 q, out float2 r) {
				float time = _TimeFactor * _Time.y;
				q.x = fbm(p + 0.00*time);
				q.y = fbm(p + float2(1.0, 1.0));
				r.x = fbm(p + 1.0*q + float2(1.7, 9.2) + 0.15*time);
				r.y = fbm(p + 1.0*q + float2(8.3, 2.8) + 0.126*time);
				return fbm(p + 1.0*r + 0.0* time);
			}
			//end helper functions


            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }


			float4 pLiquish(v2f i) :SV_Target{
				float2 q;
				float2 r;
				float2 c = i.uv.xy *_Scale;
				float f = pattern(c,q,r);

				float3 colors[3];
				colors[0] = float3 (_ColorA.r, _ColorA.g, _ColorA.b);
				colors[1] = float3 (_ColorB.r, _ColorB.g, _ColorB.b);
				colors[2] = float3 (_ColorC.r, _ColorC.g, _ColorC.b);

				float3 col = lerp(colors[0],colors[1],clamp((f*f)*4.0,0.0,1.0));
				col = lerp(col,colors[1],clamp(length(q),0.0,1.0));
				col = lerp(col,colors[2],clamp(length(r.x),0.0,1.0));

				float alphas[3];
				alphas[0] = float(_ColorA.a);
				alphas[1] = float(_ColorB.a);
				alphas[2] = float(_ColorC.a);

				float alph = lerp(alphas[0],alphas[1],clamp((f*f)*4.0,0.0,1.0));
				alph = lerp(alph,alphas[1],clamp(length(q),0.0,1.0));
				alph = lerp(alph,alphas[2],clamp(length(r.x),0.0,1.0));

				return  float4((0.2*f*f*f + 0.6*f*f + 0.5*f)*atan(col), alph);
			}

            ENDCG
        }
    }
}
