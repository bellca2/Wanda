//
//  ClassesViewController.swift
//  Wanda
//
//  Created by Bell, Courtney on 8/23/18.
//  Copyright © 2018 Bell, Courtney. All rights reserved.
//

import Firebase
import FirebaseAuth
import UIKit
import MessageUI

class ClassesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, WandaAlertViewDelegate, MFMailComposeViewControllerDelegate {
    @IBOutlet private var tableView: UITableView!
    @IBOutlet private var networkConnectionImage: UIImageView!
    @IBOutlet private var systemErrorImage: UIImageView!
    @IBOutlet private var noClassesView: UIView!
    private var dataManager = WandaDataManager.shared
    private var nextClassesSection = 0
    private let overlayView = UIView(frame: UIScreen.main.bounds)
    static let storyboardIdentifier = String(describing: ClassesViewController.self)

    private struct DefaultHeight {
        static let headerViewHeight: CGFloat = 50
        static let nextClassHeight: CGFloat = 118
        static let upcomingClassHeight: CGFloat = 86
        static let upcomingClassBackgroundViewHeight: CGFloat = 75
    }

    override var nibBundle: Bundle? {
        return Bundle(for: type(of: self))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.isNavigationBarHidden = false
        configureNavigationBar()
        configureTableView()
        if dataManager.needsReload {
            getWandaMother()
        }
        
        navigationController?.view.backgroundColor = WandaColors.lightPurple
        if let navigationBar = self.navigationController?.navigationBar {
            navigationBar.barTintColor = WandaColors.lightPurple
            navigationBar.isTranslucent = false
        }
    }
    
    // MARK: UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataManager.numberOfSections()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isNextClassesSection(section: section) {
            return 1
        }
        return dataManager.upcomingClasses.count
    }
    
    // MARK: UITableViewDelegate
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: ClassesHeaderView.nibName()) as? ClassesHeaderView else {
            return UIView()
        }
        let sectionHeaderText = section == nextClassesSection ? ClassStrings.nextClass : ClassStrings.upcomingClasses
        headerView.update(sectionText: sectionHeaderText)
        return headerView
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return DefaultHeight.headerViewHeight
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let heightForRow = indexPath.section == nextClassesSection ? DefaultHeight.nextClassHeight : DefaultHeight.upcomingClassHeight
        return heightForRow
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let classesTableViewCell = cell as? ClassesTableViewCell {
            // We want it to appear as if there are spaces between the table view cells.
            classesTableViewCell.backgroundColor = WandaColors.lightGrey
            if isNextClassesSection(section: indexPath.section) {
                classesTableViewCell.contentView.layer.applySketchShadow(alpha: 0.1, y: 1, blur: 2)
            } else {
                let backgroundView = UIView(frame: CGRect(x: 0, y: 0, width: classesTableViewCell.frame.size.width, height: DefaultHeight.upcomingClassBackgroundViewHeight))
                classesTableViewCell.contentView.addSubview(backgroundView)
                classesTableViewCell.contentView.sendSubview(toBack: backgroundView)
                classesTableViewCell.layoutSubviews()
                classesTableViewCell.layoutIfNeeded()
            }
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let classCell = tableView.dequeueReusableCell(withIdentifier: ClassesTableViewCell.nibName(), for: indexPath) as? ClassesTableViewCell else {
            return UITableViewCell()
        }
        configureClassCell(classCell, indexPath: indexPath)
        return classCell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let isNextClass = isNextClassesSection(section: indexPath.section)
        let classType = isNextClass ? ClassType.nextClass : ClassType.upcomingClass
        // to do ask about analytic here
        guard let wandaClass = isNextClass ? dataManager.nextClass : dataManager.upcomingClasses[indexPath.row], let wandaClassViewController = ViewControllerFactory.makeWandaClassViewController(wandaClass: wandaClass, classType: classType) else {
            return
        }
        
        let analyticsTag = isNextClass ? WandaAnalytics.classReserveSpotButtonTapped : WandaAnalytics.classUpcomingClassTapped
        logAnalytic(tag: analyticsTag)
        self.navigationController?.pushViewController(wandaClassViewController, animated: true)
    }

    // MARK: IBActions
    
    @IBAction func didTapLogoutButton() {
        logAnalytic(tag: WandaAnalytics.classLogoutButtonTapped)
        do {
            try Auth.auth().signOut()
        } catch {
            // We are currently failing silently and sending the user back to the LoginViewController.
            print("Couldn't sign user out. Returning back to Login.")
        }
        popBack(toControllerType: LoginViewController.self)
    }
    
    // MARK: Private
    
    private func configureClassCell(_ classCell: ClassesTableViewCell, indexPath: IndexPath) {
        classCell.selectionStyle = .none
        if isNextClassesSection(section: indexPath.section) {
            guard let nextClass = dataManager.nextClass else {
                return
            }
            classCell.configureClass(nextClass, isNextClass: true)
        } else {
            guard dataManager.upcomingClasses.indices.contains(indexPath.row) else {
                return
            }
            let upcomingClass = dataManager.upcomingClasses[indexPath.row]
            classCell.configureClass(upcomingClass, isNextClass: false)
            classCell.reservationButton.isHidden = true
        }
    }
    
    private func isNextClassesSection(section: Int) -> Bool {
        guard let _ = dataManager.nextClass else {
            return false
        }
        
        return section == nextClassesSection
    }
    
    private func configureNavigationBar() {
        self.navigationItem.hidesBackButton = true
        
        if let navigationBar = navigationController?.navigationBar, let leftBarButtonItem = navigationItem.leftBarButtonItem, let rightBarButtonItem = navigationItem.rightBarButtonItem {
            navigationBar.barTintColor = WandaColors.lightPurple
            leftBarButtonItem.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.white, NSAttributedString.Key.font: UIFont.wandaFontBold(size: 20)], for: .normal)
            rightBarButtonItem.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.white, NSAttributedString.Key.font: UIFont.wandaFontRegular(size: 16)], for: .normal)
        }
    }
    
    private func configureTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.tableFooterView = UIView()
        
        let classesHeaderViewNib = UINib(nibName: ClassesHeaderView.nibName(), bundle: nibBundle)
        tableView.register(classesHeaderViewNib, forHeaderFooterViewReuseIdentifier: ClassesHeaderView.nibName())
        let classesTableViewCellNib = UINib(nibName: ClassesTableViewCell.nibName(), bundle: nibBundle)
        tableView.register(classesTableViewCellNib, forCellReuseIdentifier: ClassesTableViewCell.nibName())
    }
    
    private func configureLoadingView() {
        overlayView.backgroundColor = UIColor.white.withAlphaComponent(0.4)
        let spinner = UIActivityIndicatorView(frame: UIScreen.main.bounds)
        spinner.activityIndicatorViewStyle = .whiteLarge
        spinner.color = .black
        spinner.startAnimating()
        overlayView.addSubview(spinner)
        self.view.addSubview(overlayView)
    }
    
    private func getWandaMother() {
        guard let firebaseId = dataManager.wandaMother?.firebaseId else {
            return
        }
        
        dataManager.needsReload = false
        configureLoadingView()
        dataManager.getWandaMother(firebaseId: firebaseId) { success, error in
            guard success else {
                if let error = error {
                    switch error {
                        case .networkError:
                            self.toggleErrorScreen(false, type: .networkError)
                            self.presentErrorAlert(for: .networkError)
                        default:
                            self.toggleErrorScreen(false, type: .unknown)
                            self.presentErrorAlert(for: .systemError)
                    }
                }
                self.overlayView.removeFromSuperview()
                return
            }
            
            self.toggleErrorScreen(true)
            self.dataManager.loadClasses()
            self.overlayView.removeFromSuperview()
            self.tableView.reloadData()
            if (!self.dataManager.hasCurrentClasses) {
                self.toggleErrorScreen(false, type: .noClasses)
            }
        }
    }
    
    func toggleErrorScreen(_ isHidden: Bool, type: WandaError? = nil) {
        if let type = type {
            switch type {
                case .networkError:
                    networkConnectionImage.isHidden = isHidden
                case .noClasses:
                    noClassesView.isHidden = isHidden
                default:
                    systemErrorImage.isHidden = isHidden
            }
        } else if isHidden {
            networkConnectionImage.isHidden = isHidden
            systemErrorImage.isHidden = isHidden
        }
        tableView.isHidden = !isHidden
    }
    
    // MARK: WandaAlertViewDelegate
    func didTapActionButton() {
        getWandaMother()
    }
}
