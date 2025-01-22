#pragma once
#include <queue>
#include <string>
#include <vector>
#include <fstream>
#include <sstream>
#include <iostream>
#include <algorithm>
#include <GL/glew.h>
#include <GL/glut.h>
#include <glm/glm.hpp>
#include <glm/gtc/type_ptr.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtx/rotate_vector.hpp>
#include <GLFW/glfw3.h>
#define uint unsigned int 
using namespace std;
using namespace glm;

struct Ray
{
	vec3 origin, direction;
	Ray(vec3 o, vec3 d) : origin(o), direction(normalize(d)) {}
};

struct AABB
{
	vec3 min, max;

	AABB() : min(vec3(FLT_MAX)), max(vec3(-FLT_MAX)) {}
	AABB(vec3 a, vec3 b) : min(a), max(b) {}

	void Expand(const AABB& other)
	{
		min = glm::min(min, other.min);
		max = glm::max(max, other.max);
	}

	void Expand(const vec3& point)
	{
		min = glm::min(min, point);
		max = glm::max(max, point);
	}

	float SurfaceArea()
	{
		vec3 extent = max - min;
		return 2.0f * (extent.x * extent.y + extent.x * extent.z + extent.y * extent.z);
	}
};

struct Triangle
{
	vec3 v0; float pad0;
	vec3 v1; float pad1;
	vec3 v2; float pad2;
	vec3 n; float pad3;

	Triangle(vec3 _v0, vec3 _v1, vec3 _v2) : v0(_v0), v1(_v1), v2(_v2), n(normalize(cross(_v1 - _v0, _v2 - _v0))) {}

	Triangle(vec3 _v0, vec3 _v1, vec3 _v2, vec3 _n) : v0(_v0), v1(_v1), v2(_v2), n(normalize(_n)) {}

	bool operator<(const Triangle& other) const
	{
		if (v0.x != other.v0.x) return v0.x < other.v0.x;
		if (v0.y != other.v0.y) return v0.y < other.v0.y;
		if (v0.z != other.v0.z) return v0.z < other.v0.z;
		if (v1.x != other.v1.x) return v1.x < other.v1.x;
		if (v1.y != other.v1.y) return v1.y < other.v1.y;
		if (v1.z != other.v1.z) return v1.z < other.v1.z;
		if (v2.x != other.v2.x) return v2.x < other.v2.x;
		if (v2.y != other.v2.y) return v2.y < other.v2.y;
		if (v2.z != other.v2.z) return v2.z < other.v2.z;
		return false;
	}

	void GetAABB(vec3& minCorner, vec3& maxCorner)
	{
		minCorner = min(v0, min(v1, v2));
		maxCorner = max(v0, max(v1, v2));
	}

	AABB GetAABB()
	{
		AABB box;
		box.Expand(v0);
		box.Expand(v1);
		box.Expand(v2);
		return box;
	}
};

struct BVHNode
{
	AABB box;
	BVHNode* left, * right;
	int n, index;

	BVHNode() : left(nullptr), right(nullptr), n(0), index(0) {}
};

struct FlattenedBVHNode
{
	int left, right, count, pad0;
	vec3 aabbMin; float pad1; vec3 aabbMax; float pad2;
};

struct Model
{
	vector<Triangle> triangles;

	bool LoadModel(const string& filepath)
	{
		ifstream file(filepath);
		string line;
		vector<vec3> vertices, normals;
		if (!file.is_open()) return false;

		while (getline(file, line))
		{
			istringstream s(line);
			string type, s1, s2, s3;
			float x, y, z;
			int v0, v1, v2, vn0, vn1, vn2;

			s >> type;
			if (type == "v")
			{
				s >> x >> y >> z;
				vertices.push_back(vec3(x, y, z));
			}
			//else if (type == "vn") 
			//{
			//	s >> x >> y >> z;
			//	normals.push_back(vec3(x, y, z));
			//}
			else if (type == "f")
			{
				s >> s1 >> s2 >> s3;

				v0 = stoi(s1.substr(0, s1.find('/'))) - 1;
				v1 = stoi(s2.substr(0, s2.find('/'))) - 1;
				v2 = stoi(s3.substr(0, s3.find('/'))) - 1;

				//vn0 = stoi(s1.substr(s1.find("//") + 2)) - 1;
				//vn1 = stoi(s2.substr(s2.find("//") + 2)) - 1;
				//vn2 = stoi(s3.substr(s3.find("//") + 2)) - 1;

				triangles.emplace_back(
					vertices[v0], vertices[v1], vertices[v2]
					//,normals[vn0] + normals[vn1] + normals[vn2] 
				);
			}
		}

		file.close();
		return true;
	}

	BVHNode* BuildBVH(int start, int end)
	{
		BVHNode* node = new BVHNode(); AABB box;
		for (int i = start; i < end; i++)
		{
			vec3 minCorner, maxCorner;
			triangles[i].GetAABB(minCorner, maxCorner);
			box.Expand(AABB(minCorner, maxCorner));
		}
		node->box = box;

		int count = end - start;
		if (count <= 4)
		{
			node->n = count;
			node->index = start;
			return node;
		}

		vec3 extent = box.max - box.min;
		int axis = extent.x > extent.y ? (extent.x > extent.z ? 0 : 2) : (extent.y > extent.z ? 1 : 2);

		sort(triangles.begin() + start, triangles.begin() + end,
			[axis](const Triangle& a, const Triangle& b) {
				return (a.v0[axis] + a.v1[axis] + a.v2[axis]) / 3 <
					(b.v0[axis] + b.v1[axis] + b.v2[axis]) / 3;
			});

		int mid = start + count / 2;
		node->left = BuildBVH(start, mid);
		node->right = BuildBVH(mid, end);
		return node;
	}

	BVHNode* BuildBVHSAH(int start, int end)
	{
		BVHNode* node = new BVHNode();
		AABB box;

		for (int i = start; i < end; i++)
		{
			vec3 minCorner, maxCorner;
			triangles[i].GetAABB(minCorner, maxCorner);
			box.Expand(AABB(minCorner, maxCorner));
		}
		node->box = box;

		int count = end - start;
		if (count <= 4)
		{
			node->n = count;
			node->index = start;
			return node;
		}

		float bestCost = FLT_MAX;
		int bestAxis = -1, bestSplit = -1;

		for (int axis = 0; axis < 3; axis++)
		{
			sort(triangles.begin() + start, triangles.begin() + end,
				[axis](const Triangle& a, const Triangle& b) {
					return (a.v0[axis] + a.v1[axis] + a.v2[axis]) / 3 <
						(b.v0[axis] + b.v1[axis] + b.v2[axis]) / 3;
				});

			vector<AABB> prefixAABB(count), suffixAABB(count);
			prefixAABB[0] = triangles[start].GetAABB();
			for (int i = 1; i < count; i++)
			{
				prefixAABB[i] = prefixAABB[i - 1];
				prefixAABB[i].Expand(triangles[start + i].GetAABB());
			}

			suffixAABB[count - 1] = triangles[end - 1].GetAABB();
			for (int i = count - 2; i >= 0; i--)
			{
				suffixAABB[i] = suffixAABB[i + 1];
				suffixAABB[i].Expand(triangles[start + i].GetAABB());
			}

			for (int i = 1; i < count; i++)
			{
				float leftArea = prefixAABB[i - 1].SurfaceArea();
				float rightArea = suffixAABB[i].SurfaceArea();
				float cost = leftArea * i + rightArea * (count - i);

				if (cost < bestCost)
				{
					bestCost = cost;
					bestAxis = axis;
					bestSplit = i;
				}
			}
		}

		sort(triangles.begin() + start, triangles.begin() + end,
			[bestAxis](const Triangle& a, const Triangle& b) {
				return (a.v0[bestAxis] + a.v1[bestAxis] + a.v2[bestAxis]) / 3 <
					(b.v0[bestAxis] + b.v1[bestAxis] + b.v2[bestAxis]) / 3;
			});

		int mid = start + bestSplit;
		node->left = BuildBVHSAH(start, mid);
		node->right = BuildBVHSAH(mid, end);

		return node;
	}

	void SerializeBVH(vector<FlattenedBVHNode>& flattenedBVH, BVHNode* root)
	{
		if (!root) return;

		queue<pair<BVHNode*, int>> q;
		q.push({ root, -1 });

		while (!q.empty())
		{
			BVHNode* node = q.front().first;
			int index = q.front().second;
			if (index != -1)
			{
				int father = index / 10; bool isLeft = index % 10 == 0;
				if (isLeft) flattenedBVH[father].left = flattenedBVH.size();
				else flattenedBVH[father].right = flattenedBVH.size();
			}
			q.pop();

			FlattenedBVHNode flatNode;
			flatNode.aabbMin = node->box.min;
			flatNode.aabbMax = node->box.max;

			if (node->n > 0)
			{
				flatNode.left = node->index;
				flatNode.right = node->index + node->n;
				flatNode.count = node->n;
			}
			else
			{
				flatNode.count = 0;

				if (node->left) q.push({ node->left, 10 * flattenedBVH.size() });
				if (node->right) q.push({ node->right, 10 * flattenedBVH.size() + 1 });
			}

			flattenedBVH.push_back(flatNode);
		}
	}
};