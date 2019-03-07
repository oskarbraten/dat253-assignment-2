// Fra https://docs.unity3d.com/Manual/SL-VertexFragmentShaderExamples.html
//https://msdn.microsoft.com/en-us/library/windows/desktop/bb509640(v=vs.85).aspx
//https://msdn.microsoft.com/en-us/library/windows/desktop/ff471421(v=vs.85).aspx
// rand num generator http://gamedev.stackexchange.com/questions/32681/random-number-hlsl
// http://www.reedbeta.com/blog/2013/01/12/quick-and-easy-gpu-random-numbers-in-d3d11/
// https://docs.unity3d.com/Manual/RenderDocIntegration.html
// https://docs.unity3d.com/Manual/SL-ShaderPrograms.html

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

			static const uint MAXIMUM_DEPTH = 25;
			static const uint NUMBER_OF_SAMPLES = 20;

			float2 rand_seed = float2(0.0, 0.0);

			float rand() {
				float2 noise = (frac(sin(dot(rand_seed, float2(12.9898, 78.233) * 2.0)) * 43758.5453));
				return abs(noise.x + noise.y) * 0.5;
			}

			vec3 random_in_unit_sphere() {
				vec3 p;
				do {
					p = 2.0 * vec3(rand(), rand(), rand()) - vec3(1.0, 1.0, 1.0);
				} while (dot(p, p) >= 1.0);
				return p;
			}

			struct hit_record {
				float t;
				vec3 position;
				vec3 normal;
			};

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

			struct camera {
				vec3 origin;
				vec3 horizontal;
				vec3 vertical;
				vec3 lower_left_corner;
				
				ray get_ray(float u, float v) {
					return ray::from(origin, lower_left_corner + u * horizontal + v * vertical);
				}

				static camera create() {
					camera c;

					c.lower_left_corner = vec3(-2, -1, -1);
					c.horizontal = vec3(4, 0, 0);
					c.vertical = vec3(0, 2, 0);
					c.origin = vec3(0, 0, 0);

					return c;
				}
			};

			struct sphere
			{
				vec3 center;
				float radius;

				static sphere from(vec3 center, float radius) {
					sphere s;
					s.center = center;
					s.radius = radius;

					return s;
				}

				bool intersect(ray r, float t_min, float t_max, out hit_record record) {
					vec3 oc = r.origin - center;
					float a = dot(r.direction, r.direction);
					float b = dot(oc, r.direction);
					float c = dot(oc, oc) - radius*radius;

					float discriminant = b * b - a * c;

					if (discriminant > 0) {
						float solution = (-b - sqrt(discriminant)) / a;
						if (solution < t_max && solution > t_min) {
							record.t = solution;
							record.position = r.point_at(record.t);
							record.normal = (record.position - center) / radius;
							return true;
						}
						solution = (-b + sqrt(discriminant)) / a;
						if (solution < t_max && solution > t_min) {
							record.t = solution;
							record.position = r.point_at(record.t);
							record.normal = (record.position - center) / radius;
							return true;
						}
					}
					return false;
				}
			};

			static const uint NUMBER_OF_SPHERES = 2;
			static const sphere WORLD[NUMBER_OF_SPHERES] = {
				{ vec3(0.0, 0.0, -1.0), 0.5 },
				{ vec3(0.0, -100.5, -1.0), 100.0 }
			};

			bool intersect_world(ray r, float t_min, float t_max, out hit_record record) {
				hit_record temp_record;
				bool intersected = false;
				float closest = t_max;

				for (uint i = 0; i < NUMBER_OF_SPHERES; i++) {
					sphere s = WORLD[i];
					if (s.intersect(r, t_min, closest, temp_record)) {
						intersected = true;
						closest = temp_record.t;
						record = temp_record;
					}
				}

				return intersected;
			}

			vec3 background(ray r) {
				float t = 0.5 * (normalize(r.direction).y + 1.0);
				return lerp(vec3(1.0, 1.0, 1.0), vec3(0.5, 0.7, 1.0), t);
			}

			vec3 trace(ray r) {

				vec3 color = vec3(1.0, 1.0, 1.0);

				hit_record record;

				uint i = 0;
				while ((i <= MAXIMUM_DEPTH) && intersect_world(r, 0.001, 100000.0, record)) {

					vec3 target = record.position + record.normal + random_in_unit_sphere();
					r = ray::from(record.position, target - record.position);

					color *= 0.5; // absorbs 50% of the energy.

					i += 1;
				}

				if (i == MAXIMUM_DEPTH) {
					return vec3(0.0, 0.0, 0.0);
				}
				else {
					return color * background(r);
				}
			}

			fixed4 frag(v2f i) : SV_Target
			{
				camera cam = camera::create();

				float u = i.uv.x;
				float v = i.uv.y;

				rand_seed = float2(u, v); // initialize random generator seed. TODO: fix random number generator.

				col3 col = col3(0.0, 0.0, 0.0);

				for (uint i = 0; i < NUMBER_OF_SAMPLES; i++) {
					ray r = cam.get_ray(u, v);
					col += col3(trace(r));
				}

				col /= NUMBER_OF_SAMPLES;

				col = sqrt(col); // gamma correction.

				return fixed4(col, 1.0);
			}
			
			ENDCG
		}
	}
}