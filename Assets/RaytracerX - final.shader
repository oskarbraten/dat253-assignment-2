Shader "Unlit/SingleColor"
{
	Properties{
		_NumberOfSamples ("Number of samples", Int) = 10
		_MaximumDepth ("Maximum depth", Int) = 25
		[MaterialToggle] _Antialiasing ("Anti-aliasing", Float) = 1
	}
	SubShader
	{
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			typedef vector <float, 4> vec4;
			typedef vector <float, 3> vec3;
			typedef vector <float, 2> vec2;
			typedef vector <fixed, 3> col3;
			typedef vector <fixed, 4> col4;
	
			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float3 ray_direction : TEXCOORD1;
				float4 vertex : SV_POSITION;
			};

			uniform float4x4 _InverseProjection;
	
			v2f vert(appdata data_in)
			{
				float4 pos = UnityObjectToClipPos(data_in.vertex);

				v2f data_out;
				data_out.vertex = pos;
				data_out.ray_direction = mul(_InverseProjection, float4(pos.x, pos.y, -1.0, 1.0));
				data_out.uv = data_in.uv;
				return data_out;
			}

			uniform float4x4 _CameraMatrix;

			uniform uint _MaximumDepth;
			uniform uint _NumberOfSamples;
			uniform uint _Antialiasing;

			static const uint MAX_NUMBER_OF_SPHERES = 500; // do not modify.

			uniform uint _NumberOfSpheres;

			uniform float4 _SpherePosition[MAX_NUMBER_OF_SPHERES];
			uniform float _SphereRadius[MAX_NUMBER_OF_SPHERES];

			uniform fixed4 _SphereMaterialAlbedo[MAX_NUMBER_OF_SPHERES];
			uniform float _SphereMaterialType[MAX_NUMBER_OF_SPHERES];
			uniform float _SphereMaterialFuzz[MAX_NUMBER_OF_SPHERES];
			uniform float _SphereMaterialRefractiveIndex[MAX_NUMBER_OF_SPHERES];

			static float rand_seed = 12.0;
			static float2 rand_uv = float2(0.0, 0.0);

			float noise(in vec2 coordinate) {
				float2 noise = frac(sin(dot(coordinate, float2(12.9898, 78.233) * 2.0)) * 43758.5453);
				return abs(noise.x + noise.y) * 0.5;
			}

			static float random_number() {
				float2 uv = float2(rand_uv.x + rand_seed, rand_uv.y + rand_seed);
				float random = noise(uv);
				rand_seed += 0.21342;

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

			struct sphere
			{
				static bool intersect(uint index, ray r, float t_min, float t_max, out hit_record record) {

					vec3 center = _SpherePosition[index];
					float radius = _SphereRadius[index];

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

				static bool scatter(uint index, ray r, hit_record record, out vec3 attenuation, out ray scattered) {

					vec3 albedo = _SphereMaterialAlbedo[index];
					uint type = (uint) _SphereMaterialType[index];
					float fuzz = _SphereMaterialFuzz[index];
					float refractive_index = _SphereMaterialRefractiveIndex[index];

					if (type == 1) {
						vec3 reflected = reflect(normalize(r.direction), record.normal);
						scattered = ray::from(record.position, reflected + fuzz * random_in_unit_sphere());
						attenuation = albedo;
						return (dot(scattered.direction, record.normal) > 0);
					}
					else if (type == 2) {
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

			bool intersect_world(ray r, float t_min, float t_max, out hit_record record) {
				hit_record temp_record;
				bool intersected = false;
				float closest = t_max;

				for (uint i = 0; i < _NumberOfSpheres; i++) {
					
					if (sphere::intersect(i, r, t_min, closest, temp_record)) {
						intersected = true;
						closest = temp_record.t;
						record = temp_record;
						record.index = i;
					}
				}

				return intersected;
			}

			vec3 background(ray r) {
				float3 direction = mul(_CameraMatrix, r.direction).xyz;
				float t = 0.5 * (normalize(direction).y + 1.0);
				return lerp(vec3(1.0, 1.0, 1.0), vec3(0.5, 0.7, 1.0), t);
			}

			vec3 trace(ray r) {

				vec3 color = vec3(1.0, 1.0, 1.0);

				hit_record record;

				uint i = 0;
				while ((i <= _MaximumDepth) && intersect_world(r, 0.001, 100000.0, record)) {

					ray scattered;
					vec3 attenuation;

					sphere::scatter(record.index, r, record, attenuation, scattered);

					r = scattered;
					color *= attenuation; // may absorb some energy.

					i += 1;
				}

				if (i == _MaximumDepth) {
					return vec3(0.0, 0.0, 0.0);
				}
				else {
					return color * background(r);
				}
			}

			fixed4 frag(v2f data_in) : SV_Target
			{
				float3 direction = normalize(data_in.ray_direction);

				float u = data_in.uv.x;
				float v = data_in.uv.y;
				rand_uv = data_in.uv; // initialize random generator seed.

				col3 col = col3(0.0, 0.0, 0.0);

				for (uint i = 0; i < _NumberOfSamples; i++) {
					float du = (random_number() / _ScreenParams.x);
					float dv = (random_number() / _ScreenParams.y);
					float3 aa = float3(du, dv, 0.0) * _Antialiasing;

					ray r = ray::from(float3(0.0, 0.0, 0.0), direction + aa);

					col += col3(trace(r));
				}

				col /= _NumberOfSamples;

				col = sqrt(col); // gamma correction.

				return fixed4(col, 1.0);
			}
			
			ENDCG
		}
	}
}