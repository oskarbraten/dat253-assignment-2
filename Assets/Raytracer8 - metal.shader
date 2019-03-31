Shader "Unlit/SingleColor"
{
	SubShader
	{
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			typedef vector <float, 3> vec3;
			typedef vector <float, 2> vec2;
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

			static const uint MAXIMUM_DEPTH = 15;
			static const uint NUMBER_OF_SAMPLES = 20;

			static float rand_seed = 0.0;
			static float2 rand_uv = float2(0.0, 0.0);

			float noise(in vec2 coordinate) {
				float2 noise = frac(sin(dot(coordinate, float2(12.9898, 78.233) * 2.0)) * 43758.5453);
				return abs(noise.x + noise.y) * 0.5;
			}

			static float random_number() {
				float2 uv = float2(rand_uv.x + rand_seed, rand_uv.y + rand_seed);
				float random = noise(uv);
				rand_seed += 0.01;

				return random;
			}

			vec3 random_in_unit_sphere() {
				vec3 p;
				do {
					p = 2.0 * vec3(random_number(), random_number(), random_number()) - vec3(1.0, 1.0, 1.0);
				} while (dot(p, p) >= 1.0);
				return p;
			}

			struct hit_record {
				float t;
				vec3 position;
				vec3 normal;
				uint index;
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
					c.horizontal = vec3(4.0, 0, 0);
					c.vertical = vec3(0, 2.0, 0);
					c.origin = vec3(0, 0, 0);

					return c;
				}
			};

			struct sphere
			{
				vec3 center;
				float radius;

				bool intersect(ray r, float t_min, float t_max, out hit_record record) {
					record.index = 0;

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

				// material:
				vec3 albedo;
				bool isMetal;
				float fuzz;

				bool scatter(ray r, hit_record record, out vec3 attenuation, out ray scattered) {
					if (isMetal) {
						vec3 reflected = reflect(normalize(r.direction), record.normal);
						scattered = ray::from(record.position, reflected + fuzz * random_in_unit_sphere());
						attenuation = albedo;
						return (dot(scattered.direction, record.normal) > 0);
					}
					else {
						vec3 target = record.position + record.normal + random_in_unit_sphere();
						scattered = ray::from(record.position, target - record.position);
						attenuation = albedo;
						return true;
					}
				}
			};

			static const uint NUMBER_OF_SPHERES = 4;
			static const sphere WORLD[NUMBER_OF_SPHERES] = {
				{ vec3(0.0, 0.0, -1.0), 0.5, vec3(0.8, 0.3, 0.3), false, 0.0 },
				{ vec3(0.0, -100.5, -1.0), 100.0, vec3(0.8, 0.8, 0.0), false, 0.0 },
				{ vec3(1.0, 0.0, -1.0), 0.5, vec3(0.8, 0.6, 0.2), true, 1.0 },
				{ vec3(-1.0, 0.0, -1.0), 0.5, vec3(0.8, 0.8, 0.8), true, 0.3 }
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
						record.index = i;
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
				while ((i < MAXIMUM_DEPTH) && intersect_world(r, 0.001, 100000.0, record)) {

					ray scattered;
					vec3 attenuation;

					WORLD[record.index].scatter(r, record, attenuation, scattered);

					r = scattered;
					color *= attenuation;

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
				rand_uv = i.uv; // initialize random generator seed.

				col3 col = col3(0.0, 0.0, 0.0);

				for (uint i = 0; i < NUMBER_OF_SAMPLES; i++) {
					float du = random_number() / _ScreenParams.x;
					float dv = random_number() / _ScreenParams.y;

					ray r = cam.get_ray(u + du, v + dv);
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