//whats going on here: https://catlikecoding.com/unity/tutorials/rendering/part-13/
//and some hints here: https://forum.unity.com/threads/custom-grass-renderer-performance-question.645019/

Shader "aivo/CubePool"
{
	Properties{
			_Color("Color", Color) = (1,1,1,1)
			_Specular("SpecularColor", Color) = (0.5,0.5,0.5,1)
			_Emission("Emission", Color) = (0.5,0.5,0.5,1)

			_MainTex("Albedo (RGB)", 2D) = "white" {}
			_DisplaceYTex("DisplaceY", 2D) = "black" {}
			_DisplaceFactor("DisplaceFactor", Range(0,5)) = 1
			_Smoothness("Smoothness", Range(0,1)) = 0.5
	}
	SubShader{

			Pass{

				Tags { "LightMode" = "Deferred" }


				//stenciling
				Stencil {
					Ref 128
					Comp always
					Pass replace
				}

				LOD 200
				CULL Off
				CGPROGRAM

				#include "UnityCG.cginc"
				#include "UnityStandardUtils.cginc"

				#pragma target 5.0
				#pragma vertex myVert
				#pragma fragment myFrag

				sampler2D _MainTex;
				sampler2D _DisplaceYTex;
				half _Smoothness;
				float _DisplaceFactor;
				float4 _Specular;
				float4 _Emission;

				//the same struc we defined in c# script where we define all vertices for the cublets
				struct Point
				{
					float3 vertex;
					float3 normal;
					float4 tangent;
					float2 uv;
					float4 color;
					float2 uvHeight;
				};
				//where to write vertices to
				StructuredBuffer<Point> points;
				struct v2f {
					float4 pos : SV_POSITION;
					float3 norm : NORMAL;
					float2 uv : TEXCOORD0;
					float3 color : TEXCOORD1;
				};

				struct FragmentOutput {
					float4 gBuffer0 : SV_Target0;
					float4 gBuffer1 : SV_Target1;
					float4 gBuffer2 : SV_Target2;
					float4 gBuffer3 : SV_Target3;
				};
				v2f myVert(uint vid : SV_VertexID) {
					v2f OUT;
					//get displace value each vert with heightmap
					float4 displaceCol = tex2Dlod(_DisplaceYTex, float4(points[vid].uvHeight,0,0));
					//get each vert position
					float3 mypos = points[vid].vertex + float3(0, displaceCol.r * _DisplaceFactor , 0);
					//.. standard stuff
					OUT.pos = UnityObjectToClipPos(float4(mypos, 1));
					OUT.color = points[vid].color.rgb;
					OUT.uv = points[vid].uv;
					OUT.norm = points[vid].normal;
					return OUT;
				}
				FragmentOutput myFrag(v2f IN) {
					FragmentOutput output;
					float4 c = tex2D(_MainTex, IN.uv);
					//c.rgb *= IN.color;


					//filling up gbuffer
					//tutorial see here: https://catlikecoding.com/unity/tutorials/rendering/part-13/
					//unity specs here: https://docs.unity3d.com/Manual/RenderTech-DeferredShading.html
					output.gBuffer0 = float4(c.rgb,1);  // Diffuse color (RGB), occlusion (A).
					output.gBuffer1 = float4(_Specular.rgb,_Smoothness); //Specular color (RGB), roughness (A).
					output.gBuffer2 = float4(IN.norm * 0.5 + 0.5, 1); ////World space normal (RGB), unused (A). +reflection probes buffer.
					output.gBuffer3 = float4(_Emission.rgb, 1);	// Emission + lighting + lightmaps
					return output;
				}

				ENDCG
			}

			Pass
			{
				Tags { "LightMode" = "ShadowCaster" }
				Cull Front //if we dont do this we get awful shadow acne		
				CGPROGRAM

				#include "UnityCG.cginc"

				#pragma target 5.0
				#pragma vertex myVert
				#pragma fragment myFrag
				#pragma multi_compile_shadowcaster

				struct v2f {
					float4 pos : SV_POSITION;
					float3 norm : NORMAL;
					float2 uv : TEXCOORD0;
					float3 color : TEXCOORD2;
				};
				struct Point {
					float3 vertex;
					float3 normal;
					float4 tangent;
					float2 uv;
					float4 color;
					float2 uvHeight;
				};
				StructuredBuffer<Point> points;
				
				sampler2D _MainTex;
				sampler2D _DisplaceYTex;
				float _DisplaceFactor;
				v2f myVert(uint vid : SV_VertexID) {
					//copy paste from above
					v2f OUT;
					float4 displaceCol = tex2Dlod(_DisplaceYTex, float4(points[vid].uvHeight, 0, 0));
					float3 mypos = points[vid].vertex + float3(0, displaceCol.r * _DisplaceFactor, 0);
					OUT.pos = UnityObjectToClipPos(float4(mypos, 1));
					OUT.color = points[vid].color.rgb;
					OUT.uv = points[vid].uv;
					OUT.norm = points[vid].normal;
					return OUT;
				}
				float4 myFrag(v2f i) : COLOR {
					SHADOW_CASTER_FRAGMENT(i)
				}

				ENDCG
			}

	}
}
