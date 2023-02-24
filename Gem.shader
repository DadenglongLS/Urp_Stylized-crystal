Shader "Tals/Gemstone01"
{
    Properties
    { 
        [Header(Base)]
        _CrystalColor("碎片颜色", Color) = (1, 1, 1, 1)
        _MainTex ("碎片贴图", 2D) = "white" {}
        _SparkPower("闪光点范围",Range(0,50))=1.5
        _SparkIntensity("闪光点亮度",Range(0,10))=1.5
        [Header(Fresel)]
        _FresnelColor("菲尼尔颜色", Color) = (1, 1, 1, 1)
        _FresnelWidth("菲尼尔宽度",Range(0,3))=1.5
        _FresnelIntensity("菲尼尔亮度",Range(0,5))=1.5
        [Header(Specular)]
        _SpecularColor("高光颜色", Color) = (1, 1, 1, 1)
        _Specularpow("高光面积",Range(0,50))=20
        _SpecularIntensity("高光亮度",Range(0,5))=1.5
        [Header(noise)]
        _SmokeTexlColor("里面图案颜色", Color) = (1, 1, 1, 1)
        _SmokeTex ("里面贴图", 2D) = "white" {}
        _CrystalIOR("视差强度", Range(1, 3)) = 1.78
        
        
        

    }

    SubShader
    {
        Tags { "Queue"="Transparent""IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" }
        LOD 100
        Blend SrcAlpha OneMinusSrcAlpha
        //   Blend one one
        // cull off
        // ZWrite on

        Pass
        {
            Name "Unlit"
            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

            
            float3 Refraction_float(float3 ViewDir, float3 Normal, float IOR)
            {
                return refract(ViewDir, Normal, IOR);
            }
            

            struct Attributes
            {
                float4 positionOS       : POSITION;
                float2 uv               : TEXCOORD0;
                half3 normal :NORMAL;
                float4 tangent :TANGENT;
            };

            struct Varyings
            {
                float4 positionCS       : SV_POSITION;
                float4 uv               : TEXCOORD0;
                float fogCoord          : TEXCOORD1;
                float3 worldNormal:TEXCOORD2;
                float3 positionWS :TEXCOORD3;
                float3 tSpace0:TEXCOORD6;
                float3 tSpace1:TEXCOORD4;
                float3 tSpace2:TEXCOORD5;
            };

            CBUFFER_START(UnityPerMaterial)
                float  _CrystalIOR,_FresnelWidth;
                float4 _FresnelColor,_CrystalColor,_SpecularColor,_MainTex_ST,_SmokeTex_ST,_SmokeTexlColor;
                float _Specularpow,_FresnelIntensity,_SpecularIntensity,_SparkPower,_SparkIntensity;
                
            CBUFFER_END
            TEXTURE2D (_MainTex);SAMPLER(sampler_MainTex);
            TEXTURE2D (_SmokeTex);SAMPLER(sampler_SmokeTex);
            

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;

                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.worldNormal =TransformObjectToWorldNormal(v.normal);
                o.uv.xy = TRANSFORM_TEX(v.uv,_MainTex);
                o.uv.zw = TRANSFORM_TEX(v.uv,_SmokeTex);
                half3 worldTangent =TransformObjectToWorldDir(v.tangent.xyz);
                o.positionWS= TransformObjectToWorld(v.positionOS.xyz);
                //v.tangent.w:DCC软件中顶点UV值中的V值翻转情况.
                //unity_WorldTransformParams.w:模型缩放是否有奇数负值. 
                half tangentSign = v.tangent.w * unity_WorldTransformParams.w;
                half3 worldBinormal = cross(o.worldNormal, worldTangent) * tangentSign;
                o.tSpace0 = float3(worldTangent.x,worldBinormal.x,  o.worldNormal.x);
                o.tSpace1 = float3(worldTangent.y,worldBinormal.y,  o.worldNormal.y);
                o.tSpace2 = float3(worldTangent.z,worldBinormal.z,  o.worldNormal.z);
                o.fogCoord = ComputeFogFactor(o.positionCS.z);

                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                half4 c=1;
                float2 UV =i.uv.xy;
                
                float3 V =normalize(_WorldSpaceCameraPos-i.positionWS);
                //菲尼尔
                float ndotv=max(0,dot(normalize(i.worldNormal),V));
                float fresnel=saturate(PositivePow(1-ndotv,_FresnelWidth));
                c=fresnel*_FresnelColor*_FresnelIntensity;
                //视察映射
                float3 V1=mul(-V,float3x3(i.tSpace0.xyz,i.tSpace1.xyz,i.tSpace2.xyz)) ;
                half3 N =normalize(i.worldNormal);
                half3 N1=mul(N,float3x3(i.tSpace0.xyz,i.tSpace1.xyz,i.tSpace2.xyz)) ;
                float3 refraction=Refraction_float(-V1,N1,1/_CrystalIOR);
                float2 offset =refraction.xy/refraction.z;
                
                // 碎片采样计算
                float3 randomdir1;
                randomdir1.r= SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy+offset+_Time.y*float2(0.005,0.022)).r-0.5;
                randomdir1.g= SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy+offset+_Time.y*float2(0.033,0.042)).g-0.5;
                randomdir1.b= SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy+offset+_Time.y*float2(0.012,0.015)).b-0.5;
                // float4 randomdir2= SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv.xy+offset+_Time.y*float2(-0.05,0.015));
                // float3 randomdir=normalize(min(randomdir1,randomdir2));
                float vdotrandomdir=PositivePow(dot(randomdir1.xyz,V),_SparkPower);
                vdotrandomdir=max(0,vdotrandomdir);
                float4 spark =vdotrandomdir*_CrystalColor*_SparkIntensity;
                //里面图案采样
                float4 smoke= SAMPLE_TEXTURE2D(_SmokeTex, sampler_SmokeTex, i.uv.zw+offset+randomdir1.xy*0.005)*saturate(1-fresnel)*_SmokeTexlColor;
                smoke*=smoke.a;

                
                
                
                
                // return fresnelcolor;
                spark*=saturate(1-fresnel);
                c+=max(spark,0);
                // //高光
                Light mainlight=GetMainLight();
                float3 L=mainlight.direction;
                float3 H =normalize(L+V);
                float ndoth =max(0,dot(N,H));
                float4 specularcolor=pow(ndoth,_Specularpow)*_SpecularColor*_SpecularIntensity;
                // return specularcolor;
                c+=specularcolor+smoke;
                // c*=_BaseColor;
                

                
                c.rgb = MixFog(c.rgb, i.fogCoord);
                return c;
            }
            ENDHLSL
        }
    }
}
