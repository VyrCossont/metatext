// Copyright © 2020 Metabolist. All rights reserved.

import Combine
import Foundation
import Mastodon
import ServiceLayer

public class AttachmentUploadViewModel: ObservableObject {
    public let id = Id()
    public let progress = Progress(totalUnitCount: 1)
    public let parentViewModel: ComposeStatusViewModel

    let data: Data
    let mimeType: String
    let description: String?
    let focus: Attachment.Meta.Focus?
    var cancellable: AnyCancellable?

    init(
        data: Data,
        mimeType: String,
        description: String?,
        focus: Attachment.Meta.Focus?,
        parentViewModel: ComposeStatusViewModel
    ) {
        self.data = data
        self.mimeType = mimeType
        self.description = description
        self.focus = focus
        self.parentViewModel = parentViewModel
    }
}

public extension AttachmentUploadViewModel {
    typealias Id = UUID

    func upload() -> AnyPublisher<Attachment, Error> {
        parentViewModel.identityContext.service.uploadAttachment(
            data: data,
            mimeType: mimeType,
            description: description,
            focus: focus,
            progress: progress
        )
    }

    func cancel() {
        cancellable?.cancel()
    }
}
