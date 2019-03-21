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

			static const uint MAXIMUM_DEPTH = 40;
			static const uint NUMBER_OF_SAMPLES = 50;

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

			float schlick(float cosine, float refractive_index) {
				float r0 = (1.0 - refractive_index) / (1.0 + refractive_index);
				r0 = r0 * r0;
				return r0 + (1.0 - r0) * pow((1.0 - cosine), 5);
			}

			// TODO: use built-in function instead.
			bool refract_2(vec3 v, vec3 n, float ni_over_nt, out vec3 refracted) {
				vec3 uv = normalize(v);
				float dt = dot(uv, n);
				float discriminant = 1.0 - ni_over_nt * ni_over_nt*(1 - dt * dt);
				if (discriminant > 0) {
					refracted = ni_over_nt * (uv - n * dt) - n * sqrt(discriminant);
					return true;
				}
				
				return false;
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

			static const float M_PI = 3.14159265f;

			struct camera {
				vec3 origin;
				vec3 horizontal;
				vec3 vertical;
				vec3 lower_left_corner;
				
				ray get_ray(float s, float t) {
					return ray::from(origin, lower_left_corner + s * horizontal + t * vertical - origin);
				}

				static camera create(vec3 look_from, vec3 look_at, vec3 up, float vfov, float aspect) {
					camera c;
					c.origin = look_from;

					vec3 u, v, w;

					float theta = vfov * M_PI / 180.0;
					float half_height = tan(theta / 2.0);
					float half_width = aspect * half_height;

					w = normalize(look_from - look_at);
					u = normalize(cross(up, w));
					v = cross(w, u);

					c.lower_left_corner = look_from - half_width * u - half_height * v - w;
					c.horizontal = 2 * half_width * u;
					c.vertical = 2 * half_height * v;

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

				/* Material */
				static const uint DIFFUSE = 0;
				static const uint METAL = 1;
				static const uint DIELECTRIC = 2;

				vec3 albedo;
				uint type; /* 0: diffuse, 1: metal, 2: dielectric*/
				float fuzz;
				float refractive_index;

				bool scatter(ray r, hit_record record, out vec3 attenuation, out ray scattered) {
					if (this.type == 1) {
						vec3 reflected = reflect(normalize(r.direction), record.normal);
						scattered = ray::from(record.position, reflected + fuzz * random_in_unit_sphere());
						attenuation = albedo;
						return (dot(scattered.direction, record.normal) > 0);
					}
					else if (this.type == 2) {
						vec3 outward_normal;
						vec3 reflected = reflect(normalize(r.direction), record.normal);

						float ni_over_nt;
						attenuation = vec3(1.0, 1.0, 1.0);

						float cosine;

						if (dot(r.direction, record.normal) > 0) {
							outward_normal = -record.normal;
							ni_over_nt = refractive_index;
							cosine = dot(r.direction, record.normal) / length(r.direction);
							cosine = sqrt(1.0 - refractive_index * refractive_index * (1.0 - cosine * cosine));
						}
						else {
							outward_normal = record.normal;
							ni_over_nt = 1.0 / refractive_index;
							cosine = -dot(r.direction, record.normal) / length(r.direction);
						}

						vec3 refracted;

						float reflect_prob;
						if (refract_2(r.direction, outward_normal, ni_over_nt, refracted)) {
							reflect_prob = schlick(cosine, refractive_index);
						}
						else {
							reflect_prob = 1.0;
						}

						if (random_number() < reflect_prob) {
							scattered = ray::from(record.position, reflected);
						}
						else {
							scattered = ray::from(record.position, refracted);
						}

						return true;
					}
					else {
						vec3 target = record.position + record.normal + random_in_unit_sphere();
						scattered = ray::from(record.position, target - record.position);
						attenuation = albedo;
						return true;
					}
				}
			};

			static const uint NUMBER_OF_SPHERES = 5;
			static const sphere WORLD[NUMBER_OF_SPHERES] = {
				{ vec3(0.0, 0.0, -1.0), 0.5, vec3(0.8, 0.3, 0.3), sphere::DIFFUSE, 0.0, 1.0 },
				{ vec3(0.0, -100.5, -1.0), 100.0, vec3(0.8, 0.8, 0.0), sphere::DIFFUSE, 0.0, 1.0 },
				{ vec3(1.0, 0.0, -1.0), 0.5, vec3(0.8, 0.6, 0.2), sphere::METAL, 1.0, 1.0 },
				{ vec3(-1.0, 0.0, -1.0), 0.5, vec3(1.0, 1.0, 1.0), sphere::DIELECTRIC, 0.0, 1.5 },
				{ vec3(-1.0, 0.0, -1.0), -0.45, vec3(1.0, 1.0, 1.0), sphere::DIELECTRIC, 0.0, 1.5 }
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
				while ((i <= MAXIMUM_DEPTH) && intersect_world(r, 0.001, 100000.0, record)) {

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
				camera cam = camera::create(vec3(-2, 2, 1), vec3(0, 0, -1), vec3(0, 1, 0), 90, 4.0/2.0);

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