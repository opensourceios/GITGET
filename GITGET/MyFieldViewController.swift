//
//  MyFieldViewController.swift
//  GITGET
//
//  Created by Bo-Young PARK on 9/11/2017.
//  Copyright © 2017 Bo-Young PARK. All rights reserved.
//

import UIKit

import FirebaseAuth
import FirebaseDatabase

import Alamofire
import SwiftyJSON
import SwiftSoup
import Kingfisher
import Toaster

class MyFieldViewController: UIViewController {
    
    /********************************************/
    //MARK:-      Variation | IBOutlet          //
    /********************************************/
    @IBOutlet weak var userProfileImageView: UIImageView!
    @IBOutlet weak var userNameTextLabel: UILabel!
    @IBOutlet weak var userLocationTextLabel: UILabel!
    @IBOutlet weak var userBioTextLabel: UILabel!
    @IBOutlet weak var todayContributionsCountLabel: UILabel!
    @IBOutlet weak var locationLogoImageView: UIImageView!
    @IBOutlet weak var mainActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var refreshActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var refreshDataButtonOutlet: UIButton!
    
    var ref: DatabaseReference!
    
    let currentUser:User? = Auth.auth().currentUser
    let accessToken:String? = UserDefaults.standard.object(forKey: "AccessToken") as? String
    let currentGitHubID:String? = UserDefaults(suiteName: "group.devfimuxd.TodayExtensionSharingDefaults")?.value(forKey: "GitHubID") as? String
    let themeRawValue:Int? = UserDefaults(suiteName: "group.devfimuxd.TodayExtensionSharingDefaults")?.value(forKey: "ThemeNameRawValue") as? Int
    let isNotNowTapped:Bool? = UserDefaults.standard.value(forKey: "isNotNowTapped") as? Bool
    
    var hexColorCodesArray:[String]?{
        didSet{
            guard let realHexColorCodes = hexColorCodesArray,
                let userDefaults = UserDefaults(suiteName: "group.devfimuxd.TodayExtensionSharingDefaults") else {return}
            
            userDefaults.setValue(realHexColorCodes, forKey: "ContributionsDatas")
            userDefaults.synchronize()
        }
    }
    
    var dateArray:[String]?{
        didSet{
            guard let realDateArray = dateArray,
                let userDefaults = UserDefaults(suiteName: "group.devfimuxd.TodayExtensionSharingDefaults") else {return}
            userDefaults.setValue(realDateArray, forKey: "ContributionsDates")
            userDefaults.synchronize()
        }
    }
    
    
    /********************************************/
    //MARK:-            LifeCycle               //
    /********************************************/
    override func viewDidLoad() {
        super.viewDidLoad()

        /** Version Control Using Firebase */
        ref = Database.database().reference()
        
        ref.child("GitgetVersion").observeSingleEvent(of: .value, with: { snapShot in
            guard let dic = snapShot.value as? Dictionary<String, AnyObject>,
                let forceUpdateMessage = dic["force_update_message"] as? String,
                let optionalUpdateMessage = dic["optional_update_message"] as? String,
                let lastestVersionCode = dic["lastest_version_code"] as? String,
                let lastestVersionName = dic["lastest_version_name"] as? String,
                let minimumVersionCode = dic["minimum_version_code"] as? String,
                let minimumVersionName = dic["minimum_version_name"] as? String else {return}
            
            let vData = GitgetVersion()
            
            vData.force_update_message = forceUpdateMessage
            vData.optional_update_message = optionalUpdateMessage
            vData.lastest_version_code = lastestVersionCode
            vData.lastest_version_name = lastestVersionName
            vData.minimum_version_code = minimumVersionCode
            vData.minimum_version_name = minimumVersionName
            
            self.checkUpdateVersion(dbdata: vData)
        })
        
        print("//뷰디드로드")
        
        guard let realCurrentUserUid:String = self.currentUser?.uid,
            let userDefaults = UserDefaults(suiteName: "group.devfimuxd.TodayExtensionSharingDefaults") else {print("뷰디드로드 가드"); return}
        
        userDefaults.setValue(true, forKey: "isSigned")
        userDefaults.synchronize()
        
        GitHubAPIManager.sharedInstance.isNewbie(uid: realCurrentUserUid, completionHandler: { (bool) in
            switch bool {
            case true: //신입이라면
                print("신입입니다.")
                guard let realAccessToken = self.accessToken else {return}
                GitHubAPIManager.sharedInstance.getGitHubIDForNewbie(with: realAccessToken, by: realCurrentUserUid, completionHandler: { (gitHubID) in
                    self.updateUserInfo()
                    
                    guard let userDefaults = UserDefaults(suiteName: "group.devfimuxd.TodayExtensionSharingDefaults") else {return}
                    userDefaults.setValue(gitHubID, forKey: "GitHubID")
                    userDefaults.synchronize()
                    
                    print("///뷰디드로드 신입: 로그인한 아이디 \(gitHubID)")
                    self.updateContributionDatasOf(gitHubID: gitHubID)
                })
            case false: //신입이 아니라면
                print("신입이 아닙니다.")
                GitHubAPIManager.sharedInstance.getCurrentGitHubID(completionHandler: { (gitHubID) in
                    
                    guard let userDefaults = UserDefaults(suiteName: "group.devfimuxd.TodayExtensionSharingDefaults") else {print("//뷰디드로드 가드"); return}
                    userDefaults.setValue(gitHubID, forKey: "GitHubID")
                    userDefaults.synchronize()
                    
                    print("///뷰디드로드 기존: 로그인한 아이디 \(gitHubID)")
                        self.updateContributionDatasOf(gitHubID: gitHubID)
                        self.updateUserInfo()
                })
            }
        })
        
        userProfileImageView.layer.cornerRadius = 10
        userProfileImageView.layer.shadowRadius = 1
        userProfileImageView.layer.shadowOpacity = 0.2
        userProfileImageView.layer.shadowOffset = CGSize(width: 1, height: 1)
        userProfileImageView.clipsToBounds = false
        
        self.refreshActivityIndicator.stopAnimating()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.navigationController?.navigationBar.isHidden = false
        
        if currentUser == nil {
            print("///뷰윌어피어: 현재유저가 없습니다. \(currentUser)")
            guard let userDefaults = UserDefaults(suiteName: "group.devfimuxd.TodayExtensionSharingDefaults") else {return}
            userDefaults.setValue(false, forKey: "isSigned")
            userDefaults.setValue(nil, forKey: "GitHubID")
            userDefaults.synchronize()

//            let navigationController:UINavigationController = self.storyboard?.instantiateViewController(withIdentifier: "NavigationController") as! UINavigationController
//            self.present(navigationController, animated: false, completion: nil)
        }else{
            print("///뷰윌어피어: 현재로그인한 유저. \(currentUser)")
            guard let userDefaults = UserDefaults(suiteName: "group.devfimuxd.TodayExtensionSharingDefaults") else {return}
            userDefaults.setValue(true, forKey: "isSigned")
            userDefaults.synchronize()

            if let realGitHubID = self.currentGitHubID { //만약 기존의 UserDefault에 저장된 아이디가 있다면,
                print("///뷰윌어피어: 로그인 유저디폴트 아이디 \(realGitHubID)")
                self.updateContributionDatasOf(gitHubID: realGitHubID)
                self.updateUserInfo()
            }else{// 업데이트 등으로 UserDefault에 저장된 아이디가 없다면
                GitHubAPIManager.sharedInstance.getCurrentGitHubID(completionHandler: { (gitHubID) in
                    print("///뷰윌어피어: 로그인한 아이디 \(gitHubID)")
                    self.updateContributionDatasOf(gitHubID: gitHubID)
                    self.updateUserInfo()
                })
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    /********************************************/
    //MARK:-       Methods | IBAction           //
    /********************************************/
    
    @IBAction func refreshDataButtonAction(_ sender: UIButton) {
        self.refreshDataButtonOutlet.isHidden = true
        self.refreshActivityIndicator.startAnimating()
        
        self.updateUserInfo()
    }
    
    func updateUserInfo() {
        print("updateUserInfo")
        GitHubAPIManager.sharedInstance.getCurrentUserDatas { (userData) in
             print("updateUserInfo 클로저")
            guard let profileUrlString = userData["profileImageUrl"],
                let location = userData["location"],
                let bio = userData["bio"],
                let name = userData["name"],
                let githubID = userData["githubID"]
                else {print("updateUserInfo 가드: \(userData)"); return}
            
             print("updateUserInfo 가드 통과")
            self.userProfileImageView.kf.indicatorType = .activity
            self.userProfileImageView.kf.indicator?.startAnimatingView()
            self.userProfileImageView.kf.setImage(with: URL(string:profileUrlString), options: [.forceRefresh], completionHandler: { [unowned self] (image, error, cache, url) in
                self.userProfileImageView.kf.indicator?.stopAnimatingView()
            })
            
            if location != "" && location != nil {
                self.locationLogoImageView.isHidden = false
            }else{
                self.locationLogoImageView.isHidden = true
            }
            self.userLocationTextLabel.text = location
            self.userBioTextLabel.text = bio
            
            if name != "" && name != nil {
                self.userNameTextLabel.text = name
            }else{
                self.userNameTextLabel.text = githubID
            }
            
            self.refreshActivityIndicator.stopAnimating()
            self.refreshDataButtonOutlet.isHidden = false
            self.mainActivityIndicator.stopAnimating()
        }
        
        GitHubAPIManager.sharedInstance.getTodayContributionsCount { (todayContributions) in
            self.todayContributionsCountLabel.text = todayContributions
        }
        
    }
    
    func updateContributionDatasOf(gitHubID:String) {
        GitHubAPIManager.sharedInstance.getContributionsColorCodeArray(gitHubID: gitHubID, theme: ThemeName(rawValue: self.themeRawValue ?? 0)) { (contributionsColorCodeArray) in
            self.hexColorCodesArray = contributionsColorCodeArray
        }
        
        GitHubAPIManager.sharedInstance.getContributionsDateArray(gitHubID: gitHubID) { (contributionsDateArray) in
            self.dateArray = contributionsDateArray
        }
    }
    
    func checkUpdateVersion(dbdata:GitgetVersion) {
        let appLastestVersion = dbdata.lastest_version_code as String
        let appMinimumVersion = dbdata.minimum_version_code as String
        
        let infoDic         = Bundle.main.infoDictionary!
        let appBuildVersion = infoDic["CFBundleVersion"] as? String
        
        if (Int(appBuildVersion!)! < Int(appMinimumVersion)!) {
            //강제업데이트
            forceUdpateAlert(message: dbdata.force_update_message)
        }else if(Int(appBuildVersion!)! < Int(appLastestVersion)!) {
            //선택업데이트
            optionalUpdateAlert(message: dbdata.optional_update_message, version: Int(dbdata.lastest_version_code)!)
        }
    }
    
    func forceUdpateAlert(message:String) {
        
        let refreshAlert = UIAlertController(title: "Update Available".localized, message: message, preferredStyle: UIAlertControllerStyle.alert)
        
        refreshAlert.addAction(UIAlertAction(title: "OK".localized, style: .default, handler: { (action: UIAlertAction!) in
            print("Go to AppStore")
            // AppStore 로 가도록 연결시켜 주면 됩니다.
            if let url = URL(string: "itms-apps://itunes.apple.com/us/app/gitget/id1317170245?mt=8"),
                UIApplication.shared.canOpenURL(url)
            {
                if #available(iOS 10.0, *) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                } else {
                    UIApplication.shared.openURL(url)
                }
            }
        }))
        
        self.present(refreshAlert, animated: true, completion: nil)
        
    }
    
    func optionalUpdateAlert(message:String, version:Int) {
        
        let refreshAlert = UIAlertController(title: "Update Available".localized, message: message, preferredStyle: UIAlertControllerStyle.alert)
        
        refreshAlert.addAction(UIAlertAction(title: "Update".localized, style: .default, handler: { (action: UIAlertAction!) in
            print("Go to AppStore")
            UserDefaults.standard.setValue(false, forKey: "isNotNowTapped")
            if let url = URL(string: "itms-apps://itunes.apple.com/us/app/gitget/id1317170245?mt=8"),
                UIApplication.shared.canOpenURL(url)
            {
                if #available(iOS 10.0, *) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                } else {
                    UIApplication.shared.openURL(url)
                }
            }
            
        }))
        
        refreshAlert.addAction(UIAlertAction(title: "Not Now".localized, style: .cancel, handler: { (action: UIAlertAction!) in
            print("Close Alert")
            Toast.init(text: "It is recommended that you update the GitGet to the latest version.\nPlease update it in Setting".localized).show()
            UserDefaults.standard.setValue(true, forKey: "isNotNowTapped")
        }))
        
        if let isNotNowTapped = self.isNotNowTapped {
            switch isNotNowTapped {
            case true:
                print("User Tapped Not Now before")
            case false:
                self.present(refreshAlert, animated: true, completion: nil)
            }
        }
        self.present(refreshAlert, animated: true, completion: nil)
    }
}

extension String {
    var localized:String {
        return NSLocalizedString(self, comment: "")
    }
    
    func localizedWithComment(comment:String) -> String {
        return NSLocalizedString(self, comment: comment)
    }
}




