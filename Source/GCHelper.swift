// GCHelper.swift (v. 0.2)
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

protocol GCHelperDelegate {
    func matchStarted()
    func match(match: GKMatch, didReceiveData: NSData, fromPlayer: String)
    func matchEnded()
}

class GCHelper: NSObject, GKMatchmakerViewControllerDelegate, GKGameCenterControllerDelegate, GKMatchDelegate, GKLocalPlayerListener {
    
    var presentingViewController: UIViewController!
    var match: GKMatch!
    var delegate: GCHelperDelegate?
    var playersDict = [String:AnyObject]()
    var invitedPlayer: GKPlayer!
    var invite: GKInvite!
    
    var matchStarted = false
    var authenticated = false
    
    class var match: GKMatch {
        get {
            return GCHelper.sharedInstance.match
        }
    }
    
    class var sharedInstance: GCHelper {
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
            println("Authentication changed: player authenticated")
            authenticated = true
        } else {
            println("Authentication changed: player not authenticated")
            authenticated = false
        }
    }
    
    func lookupPlayers() {
        let playerIDs = match.players.map { ($0 as GKPlayer).playerID }
        
        GKPlayer.loadPlayersForIdentifiers(playerIDs) { (players, error) -> Void in
            if error != nil {
                println("Error retrieving player info: \(error.localizedDescription)")
                self.matchStarted = false
                self.delegate?.matchEnded()
            } else {
                for player in players {
                    println("Found player: \(player.alias)")
                    self.playersDict[player.playerID] = player
                }
                
                self.matchStarted = true
                GKMatchmaker.sharedMatchmaker().finishMatchmakingForMatch(self.match)
                self.delegate?.matchStarted()
            }
        }
    }
    
    // MARK: User functions
    
    class func authenticateLocalUser() {
        GCHelper.sharedInstance.authenticateLocalUser()
    }
    
    func authenticateLocalUser() {
        println("Authenticating local user...")
        if GKLocalPlayer.localPlayer().authenticated == false {
            GKLocalPlayer.localPlayer().authenticateHandler = { (view, error) in
                if error == nil {
                    self.authenticated = true
                } else {
                    println("\(error.localizedDescription)")
                }
            }
        } else {
            println("Already authenticated")
        }
    }
    
    class func findMatchWithMinPlayers(minPlayers: Int, maxPlayers: Int, viewController: UIViewController, delegate theDelegate: GCHelperDelegate) {
        GCHelper.sharedInstance.findMatchWithMinPlayers(minPlayers, maxPlayers: maxPlayers, viewController: viewController, delegate: theDelegate)
    }
    
    func findMatchWithMinPlayers(minPlayers: Int, maxPlayers: Int, viewController: UIViewController, delegate theDelegate: GCHelperDelegate) {
        matchStarted = false
        match = nil
        presentingViewController = viewController
        delegate = theDelegate
        presentingViewController.dismissViewControllerAnimated(false, completion: nil)
        
        let request = GKMatchRequest()
        request.minPlayers = minPlayers
        request.maxPlayers = maxPlayers
        
        let mmvc = GKMatchmakerViewController(matchRequest: request)
        mmvc.matchmakerDelegate = self
        
        presentingViewController.presentViewController(mmvc, animated: true, completion: nil)
    }
    
    class func reportAchievementIdentifier(identifier: String, percent: Double) {
        GCHelper.sharedInstance.reportAchievementIdentifier(identifier, percent: percent)
    }
    
    func reportAchievementIdentifier(identifier: String, percent: Double) {
        let achievement = GKAchievement(identifier: identifier)
        
        achievement?.percentComplete = percent
        achievement?.showsCompletionBanner = true
        GKAchievement.reportAchievements([achievement!]) { (error) -> Void in
            if error != nil {
                println("Error in reporting achievements: \(error)")
            }
        }
    }
    
    class func reportLeaderboardIdentifier(identifier: String, score: Int) {
        GCHelper.sharedInstance.reportLeaderboardIdentifier(identifier, score: score)
    }
    
    func reportLeaderboardIdentifier(identifier: String, score: Int) {
        let scoreObject = GKScore(leaderboardIdentifier: identifier)
        scoreObject.value = Int64(score)
        GKScore.reportScores([scoreObject]) { (error) -> Void in
            if error != nil {
                println("Error in reporting leaderboard scores: \(error)")
            }
        }
    }
    
    class func showGameCenter(viewController: UIViewController, viewState: GKGameCenterViewControllerState) {
        GCHelper.sharedInstance.showGameCenter(viewController, viewState: viewState)
    }
    
    func showGameCenter(viewController: UIViewController, viewState: GKGameCenterViewControllerState) {
        presentingViewController = viewController
        
        let gcvc = GKGameCenterViewController()
        gcvc.viewState = viewState
        gcvc.gameCenterDelegate = self
        presentingViewController.presentViewController(gcvc, animated: true, completion: nil)
    }
    
    // MARK: GKGameCenterControllerDelegate
    
    func gameCenterViewControllerDidFinish(gameCenterViewController: GKGameCenterViewController!) {
        presentingViewController.dismissViewControllerAnimated(true, completion: nil)
    }
    
    // MARK: GKMatchmakerViewControllerDelegate
    
    func matchmakerViewControllerWasCancelled(viewController: GKMatchmakerViewController!) {
        presentingViewController.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func matchmakerViewController(viewController: GKMatchmakerViewController!, didFailWithError error: NSError!) {
        presentingViewController.dismissViewControllerAnimated(true, completion: nil)
        println("Error finding match: \(error.localizedDescription)")
    }
    
    func matchmakerViewController(viewController: GKMatchmakerViewController!, didFindMatch theMatch: GKMatch!) {
        presentingViewController.dismissViewControllerAnimated(true, completion: nil)
        match = theMatch
        match.delegate = self
        if !matchStarted && match.expectedPlayerCount == 0 {
            println("Ready to start match!")
            self.lookupPlayers()
        }
    }
    
    // MARK: GKMatchDelegate
    
    func match(theMatch: GKMatch!, didReceiveData data: NSData!, fromPlayer playerID: String!) {
        if match != theMatch {
            return
        }
        
        delegate?.match(theMatch, didReceiveData: data, fromPlayer: playerID)
    }
    
    func match(theMatch: GKMatch!, player playerID: String!, didChangeState state: GKPlayerConnectionState) {
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
    
    func match(theMatch: GKMatch!, didFailWithError error: NSError!) {
        if match != theMatch {
            return
        }
        
        println("Match failed with error: \(error.localizedDescription)")
        matchStarted = false
        delegate?.matchEnded()
    }
    
    // MARK: GKLocalPlayerListener
    
    func player(player: GKPlayer!, didAcceptInvite inviteToAccept: GKInvite!) {
        let mmvc = GKMatchmakerViewController(invite: inviteToAccept)
        mmvc.matchmakerDelegate = self
        presentingViewController.presentViewController(mmvc, animated: true, completion: nil)
    }
    
    func player(player: GKPlayer!, didRequestMatchWithOtherPlayers playersToInvite: [AnyObject]!) {
        
    }
}
