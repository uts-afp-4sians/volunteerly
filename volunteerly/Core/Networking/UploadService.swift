import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Errors thrown by `UploadService`.
enum UploadError: Error, LocalizedError {
    /// The converted WebP data exceeds the 5 MB upload limit.
    case fileTooLarge(bytes: Int)
    /// The image data could not be converted to WebP.
    case webpConversionFailed
    /// The presigned PUT request was rejected by the storage backend.
    case putFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .fileTooLarge(let bytes):
            let mb = String(format: "%.1f", Double(bytes) / 1_048_576)
            return "Image is too large (\(mb) MB). Maximum allowed size is 5 MB."
        case .webpConversionFailed:
            return "Could not convert the image to WebP format."
        case .putFailed(let code):
            return "Upload failed with status \(code)."
        }
    }
}

/// Stateless service that converts raw image data to WebP, obtains a presigned
/// R2 PUT URL from the backend, and streams the payload directly to storage.
enum UploadService {
    private static let maxBytes = 5 * 1_048_576 // 5 MB

    /// Uploads `data` (any decodable image format) to R2 via a presigned URL.
    ///
    /// Pipeline:
    /// 1. Obtain a presigned PUT URL from `POST /uploads/presign`. When the
    ///    backend has no R2 bucket it returns an empty `upload_url`; we short
    ///    circuit to `nil` here — before any (potentially failing) image work.
    /// 2. Downscale + encode the image. WebP is preferred (it matches the
    ///    presigned `image/webp` content type), but iOS *devices* cannot encode
    ///    WebP via ImageIO — only decode it — so we fall back to JPEG there. The
    ///    Simulator runs macOS ImageIO, which *can* encode WebP.
    /// 3. Verify the result is under `maxBytes`.
    /// 4. PUT the payload with `Content-Type: image/webp` (required by the
    ///    presigned signature); accept HTTP 200 or 204 as success.
    ///
    /// - Returns: The public CDN URL, or `nil` when the backend returned an
    ///   empty `upload_url` (local-dev fallback with no R2 bucket configured).
    static func upload(
        data: Data,
        kind: Components.Schemas.UploadKind,
        programId: Int? = nil
    ) async throws -> String? {
        // Step 1: presign first, so the no-R2 case never attempts conversion.
        let client = API.makeClient()
        let output = try await client.presign_uploads_presign_post(
            query: .init(kind: kind, program_id: programId.map { Int($0) })
        )
        let presign = try output.ok.body.json

        guard !presign.upload_url.isEmpty else {
            // Local dev / no R2 bucket — treat as a no-op.
            return nil
        }

        // Step 2: downscale + encode (WebP where supported, else JPEG).
        let payload = try encodeForUpload(data)

        // Step 3: size guard
        if payload.count > maxBytes {
            throw UploadError.fileTooLarge(bytes: payload.count)
        }

        // Step 4: PUT to R2
        guard let putURL = URL(string: presign.upload_url) else {
            throw UploadError.putFailed(statusCode: 0)
        }
        var request = URLRequest(url: putURL)
        request.httpMethod = "PUT"
        request.setValue("image/webp", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await URLSession.shared.upload(
            for: request,
            from: payload
        )
        if let http = response as? HTTPURLResponse,
           http.statusCode != 200 && http.statusCode != 204 {
            throw UploadError.putFailed(statusCode: http.statusCode)
        }

        return presign.public_url
    }

    // MARK: - Private

    /// Largest edge (px) we keep for an upload — profile/banner images never
    /// need more, and this keeps payloads well under `maxBytes`.
    private static let maxPixelSize: CGFloat = 1280

    /// Downscales the image and encodes it for upload, preferring WebP and
    /// falling back to JPEG where ImageIO can't write WebP (iOS devices).
    private static func encodeForUpload(_ data: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw UploadError.webpConversionFailed
        }
        // Thumbnail downscaling also bakes in the EXIF orientation transform.
        let cgImage = downscaledImage(from: source)
            ?? CGImageSourceCreateImageAtIndex(source, 0, nil)
        guard let cgImage else {
            throw UploadError.webpConversionFailed
        }

        if webpEncodingSupported, let webp = encode(cgImage, as: .webP) {
            return webp
        }
        if let jpeg = encode(cgImage, as: .jpeg) {
            return jpeg
        }
        throw UploadError.webpConversionFailed
    }

    /// Whether this platform's ImageIO can *write* WebP. True on the macOS-based
    /// Simulator, false on iOS devices.
    private static let webpEncodingSupported: Bool = {
        let ids = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return ids.contains(UTType.webP.identifier)
    }()

    private static func downscaledImage(from source: CGImageSource) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func encode(_ cgImage: CGImage, as type: UTType) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, type.identifier as CFString, 1, nil
        ) else {
            return nil
        }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.85]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination), output.length > 0 else {
            return nil
        }
        return output as Data
    }
}
