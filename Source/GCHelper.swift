// GCHelper.swift (v. 0.2.3)
//
// Copyright (c) 2015 Jack Cook
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import GameKit

public protocol GCHelperDelegate {
    func matchStarted()
    func match(match: GKMatch, didReceiveData: NSData, fromPlayer: String)
    func matchEnded()
}

public class GCHelper: NSObject, GKMatchmakerViewControllerDelegate, GKGameCenterControllerDelegate, GKMatchDelegate, GKLocalPlayerListener {
    
    public var match: GKMatch!
    
    private var delegate: GCHelperDelegate?
    private var invite: GKInvite!
    private var invitedPlayer: GKPlayer!
    private var playersDict = [String:AnyObject]()
    private var presentingViewController: UIViewController!
    
    private var authenticated = false
    private var matchStarted = false
    
    public class var sharedInstance: GCHelper {
        struct Static {
            static let instance = GCHelper()
        }
        return Static.instance
    }
    
    override init() {
        super.init()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "authenticationChanged", name: GKPlayerAuthenticationDidChangeNotificationName, object: nil)
    }
    
    // MARK: Internal functions
    
    func authenticationChanged() {
        if GKLocalPlayer.localPlayer().authenticated && !authenticated {
            print("Authentication changed: player authenticated")
            authenticated = true
        } else {
            print("Authentication changed: player not authenticated")
            authenticated = false
        }
    }
    
    private func lookupPlayers() {
        let playerIDs = match.players.map { $0.playerID } as! [String]
        
        GKPlayer.loadPlayersForIdentifiers(playerIDs) { (players, error) -> Void in
            if error != nil {
                print("Error retrieving player info: \(error!.localizedDescription)")
                self.matchStarted = false
                self.delegate?.matchEnded()
            } else {
                guard let players = players else {
                    print("Error retrieving players; returned nil")
                    return
                }
                
                for player in players {
                    print("Found player: \(player.alias)")
                    self.playersDict[player.playerID!] = player
                }
                
                self.matchStarted = true
                GKMatchmaker.sharedMatchmaker().finishMatchmakingForMatch(self.match)
                self.delegate?.matchStarted()
            }
        }
    }
    
    // MARK: User functions
    
    public func authenticateLocalUser(showAuthDialogOnFailure showAuthDialog: Bool, var inViewController viewController: UIViewController?) {
        print("Authenticating local user...")
        if GKLocalPlayer.localPlayer().authenticated == false {
            GKLocalPlayer.localPlayer().authenticateHandler = { (view, error) in
                if showAuthDialog && view != nil {
                    if viewController == nil {
                        if let rootViewController = UIApplication.sharedApplication().delegate?.window??.rootViewController {
                            viewController = rootViewController
                        }
                    }
                    
                    if let _viewController = viewController {
                        _viewController.presentViewController(view!, animated: true, completion: nil)
                    }
                } else if error == nil {
                    self.authenticated = true
                } else {
                    print("\(error?.localizedDescription)")
                }
            }
        } else {
            print("Already authenticated")
        }
    }
    
    public func findMatchWithMinPlayers(minPlayers: Int, maxPlayers: Int, viewController: UIViewController, delegate theDelegate: GCHelperDelegate) {
        matchStarted = false
        match = nil
        presentingViewController = viewController
        delegate = theDelegate
        presentingViewController.dismissViewControllerAnimated(false, completion: nil)
        
        let request = GKMatchRequest()
        request.minPlayers = minPlayers
        request.maxPlayers = maxPlayers
        
        let mmvc = GKMatchmakerViewController(matchRequest: request)!
        mmvc.matchmakerDelegate = self
        
        presentingViewController.presentViewController(mmvc, animated: true, completion: nil)
    }
    
    public func reportAchievementIdentifier(identifier: String, percent: Double) {
        let achievement = GKAchievement(identifier: identifier)
        
        achievement.percentComplete = percent
        achievement.showsCompletionBanner = true
        GKAchievement.reportAchievements([achievement]) { (error) -> Void in
            if error != nil {
                print("Error in reporting achievements: \(error)")
            }
        }
    }
    
    public func reportLeaderboardIdentifier(identifier: String, score: Int) {
        let scoreObject = GKScore(leaderboardIdentifier: identifier)
        scoreObject.value = Int64(score)
        GKScore.reportScores([scoreObject]) { (error) -> Void in
            if error != nil {
                print("Error in reporting leaderboard scores: \(error)")
            }
        }
    }
    
    public func showGameCenter(viewController: UIViewController, viewState: GKGameCenterViewControllerState) {
        presentingViewController = viewController
        
        let gcvc = GKGameCenterViewController()
        gcvc.viewState = viewState
        gcvc.gameCenterDelegate = self
        presentingViewController.presentViewController(gcvc, animated: true, completion: nil)
    }
    
    // MARK: GKGameCenterControllerDelegate
    
    public func gameCenterViewControllerDidFinish(gameCenterViewController: GKGameCenterViewController) {
        presentingViewController.dismissViewControllerAnimated(true, completion: nil)
    }
    
    // MARK: GKMatchmakerViewControllerDelegate
    
    public func matchmakerViewControllerWasCancelled(viewController: GKMatchmakerViewController) {
        presentingViewController.dismissViewControllerAnimated(true, completion: nil)
    }
    
    public func matchmakerViewController(viewController: GKMatchmakerViewController, didFailWithError error: NSError) {
        presentingViewController.dismissViewControllerAnimated(true, completion: nil)
        print("Error finding match: \(error.localizedDescription)")
    }
    
    public func matchmakerViewController(viewController: GKMatchmakerViewController, didFindMatch theMatch: GKMatch) {
        presentingViewController.dismissViewControllerAnimated(true, completion: nil)
        match = theMatch
        match.delegate = self
        if !matchStarted && match.expectedPlayerCount == 0 {
            print("Ready to start match!")
            self.lookupPlayers()
        }
    }
    
    // MARK: GKMatchDelegate
    
    public func match(theMatch: GKMatch, didReceiveData data: NSData, fromPlayer playerID: String) {
        if match != theMatch {
            return
        }
        
        delegate?.match(theMatch, didReceiveData: data, fromPlayer: playerID)
    }
    
    public func match(theMatch: GKMatch, player playerID: String, didChangeState state: GKPlayerConnectionState) {
        if match != theMatch {
            return
        }
        
        switch state {
        case .StateConnected where !matchStarted && theMatch.expectedPlayerCount == 0:
            lookupPlayers()
        case .StateDisconnected:
            matchStarted = false
            delegate?.matchEnded()
            match = nil
        default:
            break
        }
    }
    
    public func match(theMatch: GKMatch, didFailWithError error: NSError?) {
        if match != theMatch {
            return
        }
        
        print("Match failed with error: \(error?.localizedDescription)")
        matchStarted = false
        delegate?.matchEnded()
    }
    
    // MARK: GKLocalPlayerListener
    
    public func player(player: GKPlayer, didAcceptInvite inviteToAccept: GKInvite) {
        let mmvc = GKMatchmakerViewController(invite: inviteToAccept)!
        mmvc.matchmakerDelegate = self
        presentingViewController.presentViewController(mmvc, animated: true, completion: nil)
    }
}
