/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import WebKit
import UIKit
import RxSwift
import RxCocoa
import MozillaAppServices

class FxAView: UIViewController {
    internal var presenter: FxAPresenter?
    private var webView: WKWebView
    private var networkView: NoNetworkView
    private var disposeBag = DisposeBag()
    private var url: URL?

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

    init(webView: WKWebView = WKWebView()) {
        self.webView = webView
        self.networkView = NoNetworkView.instanceFromNib()
        super.init(nibName: nil, bundle: nil)
        self.presenter = FxAPresenter(view: self, adjustManager: AdjustManager.shared)
    }

    convenience override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.init(webView: WKWebView())
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.webView.navigationDelegate = self
        self.view = self.webView
        self.setupNetworkMessage()
        self.setupNavBar()

        self.presenter?.onViewReady()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: false)
    }

    required convenience init?(coder aDecoder: NSCoder) {
        self.init(webView: WKWebView())
    }
}

extension FxAView: FxAViewProtocol {
    func loadRequest(_ urlRequest: URLRequest) {
        self.webView.load(urlRequest)
    }

    var retryButtonTapped: Observable<Void> {
        return self.networkView.retryButton.rx.tap.asObservable()
    }

    var networkDisclaimerHidden: AnyObserver<Bool> {
        return self.networkView.rx.isHidden.asObserver()
    }
}

extension FxAView: WKNavigationDelegate {
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let navigationURL = navigationAction.request.url,
           let expectedRedirectURL = URL(string: Constant.fxa.redirectURI) {
            if navigationURL.scheme == expectedRedirectURL.scheme &&
                       navigationURL.host == expectedRedirectURL.host &&
                       navigationURL.path == expectedRedirectURL.path {
               self.presenter?.matchingRedirectURLReceived(navigationURL)
                decisionHandler(.cancel)
                return
            }
        }

        decisionHandler(.allow)
    }
}

extension FxAView: UIGestureRecognizerDelegate {
    fileprivate func setupNavBar() {
        let leftButton = UIButton(title: Constant.string.close, imageName: nil)
        leftButton.titleLabel?.font = .navigationButtonFont
        leftButton.accessibilityIdentifier = "closeButtonGetStartedNavBar"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: leftButton)

        self.navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        self.navigationItem.title = Constant.string.getStarted
        self.navigationItem.largeTitleDisplayMode = .never

        if let presenter = self.presenter {
            leftButton.rx.tap
                .bind(to: presenter.onClose)
                .disposed(by: self.disposeBag)

            self.navigationController?.interactivePopGestureRecognizer?.delegate = self
            self.navigationController?.interactivePopGestureRecognizer?.rx.event
                .map { _ -> Void in
                    return ()
                }
                .bind(to: presenter.onClose)
                .disposed(by: self.disposeBag)
        }
    }

    fileprivate func setupNetworkMessage() {
        self.networkView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.networkView)
        self.networkView.addConstraint(NSLayoutConstraint(
            item: self.networkView,
            attribute: .height,
            relatedBy: .equal,
            toItem: nil,
            attribute: .height,
            multiplier: 1,
            constant: 38)
        )

        self.view.addConstraints([
            NSLayoutConstraint(
                item: self.networkView,
                attribute: .leading,
                relatedBy: .equal,
                toItem: self.view.safeAreaLayoutGuide,
                attribute: .leading,
                multiplier: 1,
                constant: 0),
            NSLayoutConstraint(
                item: self.networkView,
                attribute: .trailing,
                relatedBy: .equal,
                toItem: self.view.safeAreaLayoutGuide,
                attribute: .trailing,
                multiplier: 1,
                constant: 0),
            NSLayoutConstraint(
                item: self.networkView,
                attribute: .top,
                relatedBy: .equal,
                toItem: self.view.safeAreaLayoutGuide,
                attribute: .top,
                multiplier: 1,
                constant: 0)
            ]
        )
    }
}
