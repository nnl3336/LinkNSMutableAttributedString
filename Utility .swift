//
//  Utility .swift
//  LinkNSMutableAttributedString
//
//  Created by Yuki Sasaki on 2025/09/06.
//

import SwiftUI

final class Toast {
    // MARK: - Toast 表示
    static func showToast(message: String, duration: TimeInterval = 2.0) {
        guard let window = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
                .first else { return }

        let toastLabel = UILabel()
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        toastLabel.textColor = .white
        toastLabel.font = .systemFont(ofSize: 14)
        toastLabel.textAlignment = .center
        toastLabel.text = message
        toastLabel.alpha = 0.0
        toastLabel.numberOfLines = 0

        let padding: CGFloat = 16
        let maxWidth = window.frame.width - 2 * padding
        let textSize = toastLabel.sizeThatFits(CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude))
        toastLabel.frame = CGRect(
            x: (window.frame.width - textSize.width - padding)/2,
            y: window.frame.height - textSize.height - 100,
            width: textSize.width + padding,
            height: textSize.height + padding/2
        )
        toastLabel.layer.cornerRadius = 8
        toastLabel.layer.masksToBounds = true

        window.addSubview(toastLabel)

        UIView.animate(withDuration: 0.5, animations: {
            toastLabel.alpha = 1.0
        }) { _ in
            UIView.animate(withDuration: 0.5, delay: duration, options: [], animations: {
                toastLabel.alpha = 0.0
            }) { _ in
                toastLabel.removeFromSuperview()
            }
        }
    }
}
