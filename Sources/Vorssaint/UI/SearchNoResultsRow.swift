// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Volod1ka

import SwiftUI

/// The empty state every search shares: says the query found nothing and
/// offers to clear it, so "no matches" never reads as "nothing here at all".
/// Shown right under the search field.
struct SearchNoResultsRow: View {
    @ObservedObject private var l10n = L10n.shared
    let query: String
    /// For the menu bar panel's small cards.
    var compact = false
    let onClear: () -> Void

    private var shownQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(spacing: compact ? 7 : 10) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: compact ? 14 : 18))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("\(l10n.s.homebrewSearchEmpty) · “\(shownQuery)”")
                .font(.system(size: compact ? 11 : 13))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Button(l10n.s.actionClear, action: onClear)
                .buttonStyle(.plain)
                .font(.system(size: compact ? 11 : 13, weight: .medium))
                .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, compact ? 10 : 14)
        .padding(.vertical, compact ? 8 : 11)
        .background(Color.primary.opacity(0.055),
                    in: RoundedRectangle(cornerRadius: compact ? 9 : 11, style: .continuous))
    }

    /// True when `query` has something to search for.
    static func isActive(_ query: String) -> Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
