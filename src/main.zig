const std = @import("std");

const allocator = std.heap.page_allocator;

const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return Vec3{ .x = x, .y = y, .z = z };
    }

    pub fn add(self: Vec3, other: Vec3) Vec3 {
        return Vec3.init(self.x + other.x, self.y + other.y, self.z + other.z);
    }

    pub fn sub(self: Vec3, other: Vec3) Vec3 {
        return Vec3.init(self.x - other.x, self.y - other.y, self.z - other.z);
    }

    pub fn mul(self: Vec3, scalar: f32) Vec3 {
        return Vec3.init(self.x * scalar, self.y * scalar, self.z * scalar);
    }

    pub fn dot(self: Vec3, other: Vec3) f32 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub fn length(self: Vec3) f32 {
        return std.math.sqrt(self.dot(self));
    }

    pub fn normalize(self: Vec3) Vec3 {
        const len = self.length();
        if (len == 0) return self;
        return self.mul(1.0 / len);
    }
};

const Ray = struct {
    origin: Vec3,
    direction: Vec3,

    pub fn init(origin: Vec3, direction: Vec3) Ray {
        return Ray{ .origin = origin, .direction = direction.normalize() };
    }

    pub fn at(self: Ray, t: f32) Vec3 {
        return self.origin.add(self.direction.mul(t));
    }
};

const Sphere = struct {
    center: Vec3,
    radius: f32,

    pub fn init(center: Vec3, radius: f32) Sphere {
        return Sphere{ .center = center, .radius = radius };
    }

    pub fn hit(self: Sphere, ray: Ray, t_min: f32, t_max: f32) ?f32 {
        const oc = ray.origin.sub(self.center);
        const a = ray.direction.dot(ray.direction);
        const b = oc.dot(ray.direction) * 2.0;
        const c = oc.dot(oc) - self.radius * self.radius;
        const discriminant = b * b - 4 * a * c;
        if (discriminant < 0) return null;
        const sqrt_d = std.math.sqrt(discriminant);
        var t = (-b - sqrt_d) / (2 * a);
        if (t < t_min or t > t_max) {
            t = (-b + sqrt_d) / (2 * a);
            if (t < t_min or t > t_max) return null;
        }
        return t;
    }
};

fn rayColor(ray: Ray, sphere: Sphere) Vec3 {
    if (sphere.hit(ray, 0, std.math.inf(f32))) |_| {
        return Vec3.init(1, 0, 0);
    }
    const unit_direction = ray.direction.normalize();
    const t = 0.5 * (unit_direction.y + 1.0);
    return Vec3.init(1, 1, 1).mul(1.0 - t).add(Vec3.init(0.5, 0.7, 1.0).mul(t));
}

pub fn main() !void {
    const aspect_ratio = 16.0 / 9.0;
    const image_width = 400;
    const image_height = @as(u32, @intFromFloat(@as(f32, @floatFromInt(image_width)) / aspect_ratio));

    const viewport_height = 2.0;
    const viewport_width = viewport_height * aspect_ratio;
    const focal_length = 1.0;

    const origin = Vec3.init(0, 0, 0);
    const horizontal = Vec3.init(viewport_width, 0, 0);
    const vertical = Vec3.init(0, viewport_height, 0);
    const lower_left_corner = origin.sub(horizontal.mul(0.5)).sub(vertical.mul(0.5)).sub(Vec3.init(0, 0, focal_length));

    const sphere = Sphere.init(Vec3.init(0, 0, -1), 0.5);

    var file = try std.fs.cwd().createFile("output.ppm", .{});
    defer file.close();

    const header = try std.fmt.allocPrint(allocator, "P3\n{} {}\n255\n", .{ image_width, image_height });
    defer allocator.free(header);
    try file.writeAll(header);

    var j: i32 = image_height - 1;
    while (j >= 0) : (j -= 1) {
        var i: u32 = 0;
        while (i < image_width) : (i += 1) {
            const u = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(image_width - 1));
            const v = @as(f32, @floatFromInt(j)) / @as(f32, @floatFromInt(image_height - 1));
            const direction = lower_left_corner.add(horizontal.mul(u)).add(vertical.mul(v)).sub(origin);
            const ray = Ray.init(origin, direction);
            const color = rayColor(ray, sphere);

            const ir = @as(u8, @intFromFloat(255.999 * color.x));
            const ig = @as(u8, @intFromFloat(255.999 * color.y));
            const ib = @as(u8, @intFromFloat(255.999 * color.z));
            const line = try std.fmt.allocPrint(allocator, "{} {} {}\n", .{ ir, ig, ib });
            defer allocator.free(line);
            try file.writeAll(line);
        }
    }
}
