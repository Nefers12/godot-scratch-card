use godot::classes::Image;
use godot::prelude::*;

struct ScratchCardExtension;

#[gdextension]
unsafe impl ExtensionLibrary for ScratchCardExtension {}

#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct ScratchNativeCalculator {
    base: Base<RefCounted>,
}

#[godot_api]
impl IRefCounted for ScratchNativeCalculator {
    fn init(base: Base<RefCounted>) -> Self {
        Self { base }
    }
}

#[godot_api]
impl ScratchNativeCalculator {
    fn ensure_rgba8_image(&self, mut image: Gd<Image>) -> Gd<Image> {
        if image.is_compressed() {
            let _ = image.decompress();
        }
        if image.get_format() != godot::classes::image::Format::RGBA8 {
            image.convert(godot::classes::image::Format::RGBA8);
        }
        image
    }

    #[func]
    pub fn calculate_scratched_percentage(&self, image: Gd<Image>, threshold: u8) -> f32 {
        self.calculate_zone_scratched_percentage(
            image,
            threshold,
            Rect2::new(Vector2::new(0.0, 0.0), Vector2::new(1.0, 1.0)),
        )
    }

    #[func]
    pub fn calculate_zone_scratched_percentage(
        &self,
        image: Gd<Image>,
        threshold: u8,
        zone: Rect2,
    ) -> f32 {
        let rgba_image = self.ensure_rgba8_image(image);
        let width = rgba_image.get_width() as usize;
        let height = rgba_image.get_height() as usize;

        if width == 0 || height == 0 {
            return 0.0;
        }

        let start_x = (zone.position.x.clamp(0.0, 1.0) * width as f32) as usize;
        let end_x = ((zone.position.x + zone.size.x).clamp(0.0, 1.0) * width as f32) as usize;
        let start_y = (zone.position.y.clamp(0.0, 1.0) * height as f32) as usize;
        let end_y = ((zone.position.y + zone.size.y).clamp(0.0, 1.0) * height as f32) as usize;

        if end_x <= start_x || end_y <= start_y {
            return 0.0;
        }

        let zone_pixels = ((end_x - start_x) * (end_y - start_y)) as u64;

        let data = rgba_image.get_data();
        let slice = data.as_slice();
        if slice.is_empty() {
            return 0.0;
        }

        let mut scratched_count: u64 = 0;

        if start_x == 0 && end_x == width && start_y == 0 && end_y == height {
            for pixel in slice.chunks_exact(4) {
                scratched_count += (pixel[0] >= threshold) as u64;
            }
        } else {
            let row_stride = width * 4;
            let row_bytes = (end_x - start_x) * 4;
            let x_offset = start_x * 4;

            for y in start_y..end_y {
                let row_start = y * row_stride + x_offset;
                if let Some(row) = slice.get(row_start..row_start + row_bytes) {
                    for pixel in row.chunks_exact(4) {
                        scratched_count += (pixel[0] >= threshold) as u64;
                    }
                }
            }
        }

        scratched_count as f32 / zone_pixels as f32
    }
}