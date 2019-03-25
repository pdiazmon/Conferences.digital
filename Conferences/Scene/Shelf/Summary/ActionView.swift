//
//  ActionView.swift
//  Conferences
//
//  Created by Timon Blask on 07/02/2019.
//  Copyright © 2019 Timon Blask. All rights reserved.
//

import Cocoa

final class ActionView: NSView {
    private var talk: TalkModel?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        configureView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var watchlistButton: ImageButton = {
        let b = ImageButton(frame: .zero)
        b.height(25)
        b.width(25)

        b.target = self
        b.action = #selector(toggleWatchlist)

        b.toolTip = "Add to Watchlist"
        b.isToggle = true
        b.image = #imageLiteral(resourceName: "watchlist")
        b.alternateImage = #imageLiteral(resourceName: "watchlist_filled")

        return b
    }()

    private lazy var watchButton: ImageButton = {
        let b = ImageButton(frame: .zero)
        b.height(25)
        b.width(25)

        b.target = self
        b.action = #selector(toggleWatch)
        b.toolTip = "Mark as Watched"

        b.isToggle = true
        b.image = #imageLiteral(resourceName: "watch")
        b.alternateImage = #imageLiteral(resourceName: "watch_filled")

        return b
    }()

    private lazy var stackView: NSStackView = {
        let v = NSStackView(views: [self.watchlistButton, self.watchButton])

        v.orientation = .horizontal
        v.spacing = 10

        return v
    }()

    private func configureView() {
        addSubview(stackView)
        stackView.edgesToSuperview(insets: .init(top: 15, left: 15, bottom: 15, right: 15))
    }

    func configureView(with talk: TalkModel) {
        self.talk = talk

        watchlistButton.state = talk.onWatchlist ? .on : .off
        watchButton.state = talk.progress?.watched ?? false ? .on : .off
    }

    @objc func toggleWatch() {
        guard var talk = self.talk else { return }

        talk.watched.toggle()

        NotificationCenter.default.post(Notification(name: .buildLists))
        NotificationCenter.default.post(Notification(name: .refreshActiveCell))

        var tag = TagModel(title: "Confinue watching", query: "realm_continue", isActive: false)
        TagSyncService.shared.handleStoredTag(&tag)
    }

    @objc func toggleWatchlist() {
        guard var talk = self.talk else { return }
        talk.onWatchlist.toggle()

        var tag = TagModel(title: "Watchlist", query: "realm_watchlist", isActive: talk.onWatchlist)
        TagSyncService.shared.handleStoredTag(&tag)
    }
}
