import Foundation
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

    /// Uploads `data` (any UIImage-readable format) to R2 via a presigned URL.
    ///
    /// Conversion pipeline:
    /// 1. Decode `data` into a `CGImage`.
    /// 2. Re-encode as WebP (lossless, quality 0.85).
    /// 3. Verify the result is under `maxBytes`.
    /// 4. Obtain a presigned PUT URL from `POST /uploads/presign`.
    /// 5. PUT the WebP payload; accept HTTP 200 or 204 as success.
    ///
    /// - Returns: The public CDN URL, or `nil` when the backend returned an
    ///   empty `upload_url` (local-dev fallback with no R2 bucket configured).
    static func upload(
        data: Data,
        kind: Components.Schemas.UploadKind,
        programId: Int? = nil
    ) async throws -> String? {
        // Step 1 & 2: convert to WebP
        let webpData = try convertToWebP(data)

        // Step 3: size guard
        if webpData.count > maxBytes {
            throw UploadError.fileTooLarge(bytes: webpData.count)
        }

        // Step 4: presign
        let client = API.makeClient()
        let output = try await client.presign_uploads_presign_post(
            query: .init(kind: kind, program_id: programId.map { Int($0) })
        )
        let presign = try output.ok.body.json

        guard !presign.upload_url.isEmpty else {
            // Local dev: no R2 bucket — treat as no-op
            return nil
        }

        // Step 5: PUT to R2
        guard let putURL = URL(string: presign.upload_url) else {
            throw UploadError.putFailed(statusCode: 0)
        }
        var request = URLRequest(url: putURL)
        request.httpMethod = "PUT"
        request.setValue("image/webp", forHTTPHeaderField: "Content-Type")

        let (_, response) = try await URLSession.shared.upload(
            for: request,
            from: webpData
        )
        if let http = response as? HTTPURLResponse,
           http.statusCode != 200 && http.statusCode != 204 {
            throw UploadError.putFailed(statusCode: http.statusCode)
        }

        return presign.public_url
    }

    // MARK: - Private

    /// Converts arbitrary image data to WebP using `CGImageDestination`.
    /// Available on iOS 14+ (WebP encode support landed in iOS 14).
    private static func convertToWebP(_ data: Data) throws -> Data {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw UploadError.webpConversionFailed
        }

        let output = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                output,
                UTType.webP.identifier as CFString,
                1,
                nil
            )
        else {
            throw UploadError.webpConversionFailed
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.85
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination), output.length > 0 else {
            throw UploadError.webpConversionFailed
        }
        return output as Data
    }
}
