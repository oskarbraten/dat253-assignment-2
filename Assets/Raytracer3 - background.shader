Shader "Unlit/SingleColor"
{
	SubShader
	{
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			typedef vector <float, 3> vec3;  // to get more similar code to book
			typedef vector <fixed, 3> col3;
	
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
	
			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}
			
			struct ray
			{
				vec3 origin;
				vec3 direction;

				static ray from(vec3 origin, vec3 direction) {
					ray r;
					r.origin = origin;
					r.direction = direction;

					return r;
				}

				vec3 point_at(float t) {
					return origin + t*direction;
				}
			};

			vec3 background(ray r) {
				float t = 0.5 * (normalize(r.direction).y + 1.0);
				return lerp(vec3(1.0, 1.0, 1.0), vec3(0.5, 0.7, 1.0), t);
			}

			vec3 trace(ray r) {
				return background(r);
			}
	
			fixed4 frag(v2f i) : SV_Target
			{

				vec3 lower_left_corner = {-2, -1, -1};
				vec3 horizontal = {4, 0, 0};
				vec3 vertical = {0, 2, 0};
				vec3 origin = {0, 0, 0};

				float u = i.uv.x;
				float v = i.uv.y;

				ray r = ray::from(origin, lower_left_corner + u*horizontal + v*vertical);

				return fixed4(trace(r), 1.0);
			}
			
			ENDCG
		}
	}
}