//
//  ListViewController.swift
//  Conferences
//
//  Created by Timon Blask on 12/02/19.
//  Copyright © 2019 Timon Blask. All rights reserved.
//

import Cocoa

enum VideoFilter: String {
    case all        = "All videos"
    case notWatched = "Not watched"
    case Watched    = "Watched"
}

class ListViewController: NSViewController {

    lazy var filterTab: NSSegmentedControl = {
        let ft = NSSegmentedControl(labels: [VideoFilter.all.rawValue, VideoFilter.notWatched.rawValue, VideoFilter.Watched.rawValue], trackingMode: .selectOne, target: self, action: #selector(filterTabAction))
        
        ft.selectedSegment = 0
        
        return ft
    }()
    
    lazy var tableView: NSTableView = {
        let v = NSTableView()

        v.allowsEmptySelection = false
        v.focusRingType = .none
        v.allowsMultipleSelection = true
        v.backgroundColor = .clear
        v.headerView = nil
        v.rowHeight = 64
        v.autoresizingMask = [.width, .height]
        v.selectionHighlightStyle = .regular

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "session"))
        v.addTableColumn(column)

        return v
    }()

    lazy var scrollView: NSScrollView = {
        let v = NSScrollView()

        v.focusRingType = .none
        v.borderType = .noBorder
        v.documentView = self.tableView
        v.hasVerticalScroller = true
        v.hasHorizontalScroller = false
        v.drawsBackground = true
        v.backgroundColor = NSColor.panelBackground

        return v
    }()

    private lazy var stackView: NSStackView = {
        let v = NSStackView(views: [self.filterTab, self.scrollView])
        
        v.orientation  = .vertical
        v.alignment    = .centerX
        v.distribution = .fill
        v.spacing      = 10
        
        return v
    }()

    override func loadView() {
        view = NSView()
         view.wantsLayer = true

        //view.addSubview(scrollView)
        view.addSubview(stackView)

        stackView.edgesToSuperview(insets: .init(top: 30, left: 15, bottom: 15, right: 15))
        //scrollView.edgesToSuperview()
        scrollView.width(min: 320, max: 675, priority: .defaultHigh, isActive: true)

        NotificationCenter.default.addObserver(self, selector: #selector(reloadActiveCell), name: .refreshActiveCell, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(buildLists), name: .buildLists, object: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupContextualMenu()
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        view.window?.makeFirstResponder(tableView)
    }

    @objc func reloadActiveCell(_ notification: Notification) {
        tableView.reloadData(forRowIndexes: selectedAndClickedRowIndexes(), columnIndexes: IndexSet(integer: 0))

        // reload detailVC

        guard let shouldReloadDetailVC = notification.object as? Bool else { return }
        guard shouldReloadDetailVC == true else { return }
        guard let dataSource = tableView.dataSource as? ListViewDataSource else { return }

        if let index = selectedAndClickedRowIndexes().first {
            dataSource.didSelectIndex(at: index)
        }
    }
}

extension ListViewController: NSMenuItemValidation {

    fileprivate enum ContextualMenuOption: Int {
        case watched = 1000
        case unwatched = 1001
        case addToWatchlist = 1002
        case removeFromWatchlist = 1003
    }

    func selectedAndClickedRowIndexes() -> IndexSet {
        let clickedRow = tableView.clickedRow
        let selectedRowIndexes = tableView.selectedRowIndexes

        if clickedRow < 0 || selectedRowIndexes.contains(clickedRow) {
            return selectedRowIndexes
        } else {
            return IndexSet(integer: clickedRow)
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        for row in selectedAndClickedRowIndexes() {
            guard
                let dataSource = tableView.dataSource as? ListViewDataSource,
                let talk = dataSource.talks[row] as? TalkModel else {
                return false
            }


            if shouldEnableMenuItem(menuItem: menuItem, talk: talk) { return true}
        }

        return false
    }

    private func shouldEnableMenuItem(menuItem: NSMenuItem, talk: TalkModel) -> Bool {
        switch menuItem.option {
        case .watched:
            let canMarkAsWatched = talk.progress == nil || talk.progress?.watched == false

            return canMarkAsWatched
        case .unwatched:
            return talk.progress?.watched == true || talk.progress?.relativePosition != 0
        case .addToWatchlist:
            return !talk.onWatchlist
        case .removeFromWatchlist:
            return talk.onWatchlist
        }
    }

    private func setupContextualMenu() {
        let contextualMenu = NSMenu(title: "TableView Menu")

        let watchedMenuItem = NSMenuItem(title: "Mark as Watched", action: #selector(tableViewMenuItemClicked(_:)), keyEquivalent: "")
        watchedMenuItem.option = .watched
        contextualMenu.addItem(watchedMenuItem)

        let unwatchedMenuItem = NSMenuItem(title: "Mark as Unwatched", action: #selector(tableViewMenuItemClicked(_:)), keyEquivalent: "")
        unwatchedMenuItem.option = .unwatched
        contextualMenu.addItem(unwatchedMenuItem)

        contextualMenu.addItem(.separator())

        let favoriteMenuItem = NSMenuItem(title: "Add to Watchlist", action: #selector(tableViewMenuItemClicked(_:)), keyEquivalent: "")
        favoriteMenuItem.option = .addToWatchlist
        contextualMenu.addItem(favoriteMenuItem)

        let removeFavoriteMenuItem = NSMenuItem(title: "Remove from Watchlist", action: #selector(tableViewMenuItemClicked(_:)), keyEquivalent: "")
        removeFavoriteMenuItem.option = .removeFromWatchlist
        contextualMenu.addItem(removeFavoriteMenuItem)


        tableView.menu = contextualMenu
    }

    @objc private func tableViewMenuItemClicked(_ menuItem: NSMenuItem) {
        LoggingHelper.register(event: .rightClickonTable )

        var talks = [TalkModel]()
        guard let dataSource = tableView.dataSource as? ListViewDataSource else { return }

        selectedAndClickedRowIndexes().forEach { row in
            guard let talk = dataSource.talks[row] as? TalkModel else { return }
            talks.append(talk)
        }

        guard !talks.isEmpty else { return }

        switch menuItem.option {
        case .watched:
            let _ = talks.mapInPlace { $0.watched = true }

            var tag = TagModel(title: "Continue watching", query: "realm_continue", isActive: false)
            TagSyncService.shared.handleStoredTag(&tag)
        case .unwatched:
             let _ = talks.mapInPlace { $0.watched = false }

             var tag = TagModel(title: "Continue watching", query: "realm_continue", isActive: false)
             TagSyncService.shared.handleStoredTag(&tag)
        case .addToWatchlist:
            let _ = talks.mapInPlace { $0.onWatchlist = true }

            var tag = TagModel(title: "Watchlist", query: "realm_watchlist", isActive: true)
            TagSyncService.shared.handleStoredTag(&tag)
        case .removeFromWatchlist:
            let _ = talks.mapInPlace { $0.onWatchlist = false }

            var tag = TagModel(title: "Watchlist", query: "realm_watchlist", isActive: false)
            TagSyncService.shared.handleStoredTag(&tag)
        }

        self.tableView.reloadData(forRowIndexes: selectedAndClickedRowIndexes(), columnIndexes: IndexSet(integer: 0))

        if let index = selectedAndClickedRowIndexes().first {
            dataSource.didSelectIndex(at: index)
        }
    }
}

private extension NSMenuItem {

    var option: ListViewController.ContextualMenuOption {
        get {
            guard let value = ListViewController.ContextualMenuOption(rawValue: tag) else {
                fatalError("Invalid ContextualMenuOption: \(tag)")
            }

            return value
        }
        set {
            tag = newValue.rawValue
        }
    }

}

extension ListViewController {
    
    @objc func filterTabAction() {
        NotificationCenter.default.post(.init(name: .refreshTableView))
    }
    
    @objc func buildLists() {
        guard let dataSource = tableView.dataSource as? ListViewDataSource else { return }
        dataSource.buildLists()
        tableView.reloadData()
    }
    
}
