//
//  ViewController.swift
//  Firebase Phase 1
//
//  Created by RayShin Lee on 2022/5/16.
//

import UIKit
import FirebaseFirestore
import FirebaseCore

class ViewController: UIViewController {
    
    //MARK: - Properties
    var db: Firestore!
    
    //MARK: - Outlets
    
    @IBOutlet weak var titleOutlet: UITextField!
    @IBOutlet weak var contentOutlet: UITextField!
    @IBOutlet weak var tagOutlet: UITextField!
    @IBOutlet weak var publishButton: UIButton!
    
    @IBOutlet weak var nameOutlet: UITextField!
    @IBOutlet weak var emailOutlet: UITextField!
    @IBOutlet weak var searchOutlet: UITextField!
    
    //MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        db = Firestore.firestore()
        readArticleData()
        fetchListener()
    }
    
    //MARK: - IBAction
    
    @IBAction func publishButtonAction(_ sender: UIButton) {
        
        guard let title = titleOutlet.text,
              let content = contentOutlet.text,
              let tag = tagOutlet.text,
              !title.isEmpty,
              !content.isEmpty,
              !tag.isEmpty else {
                  let alert = UIAlertController(title: "Error", message: "Empty Input", preferredStyle: .alert)
                  let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                  alert.addAction(okAction)
                  present(alert, animated: true, completion: nil)
                  return
              }
        
        addArticleData(title: title, content: content, tag: tag)
    }
    
    @IBAction func submitButtonAction(_ sender: UIButton) {
        guard let email = emailOutlet.text,
              let name = nameOutlet.text,
              !email.isEmpty,
              !name.isEmpty else {
                  let alert = UIAlertController(title: "Error", message: "Empty Input", preferredStyle: .alert)
                  let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                  alert.addAction(okAction)
                  present(alert, animated: true, completion: nil)
                  return
              }
        
        addUserData(email: email, name: name)
        
    }
    
    @IBAction func addFriendButton(_ sender: UIButton) {
        
        guard let email = searchOutlet.text,
              !email.isEmpty else {
                  let alert = UIAlertController(title: "Error", message: "Empty Input", preferredStyle: .alert)
                  let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                  alert.addAction(okAction)
                  present(alert, animated: true, completion: nil)
                  return
              }
        
        fetchUserData(email: email)
    }
    
    //MARK: - methods
    
    func addUserData(email: String, name: String) {
        db.collection("user_data").addDocument(data: [
            "email": email,
            "name": name
        ]) { (error) in
            if let error = error {
                print(error)
            }
        }
    }
    
    func addArticleData(title: String, content: String, tag: String) {
        let timeStamp = Date()
        let uuid = UUID().uuidString
        let id = db.collection("phase_1").document().documentID
        
        db.collection("phase_1").document(id).setData([
            "id": id,
            "title": title,
            "content": content,
            "tag": tag,
            "author_id": ("rayshin_\(uuid)"),
            "created_time": timeStamp
        ]) { (error) in
            if let error = error {
                print(error)
            }
        }
        
//        db.collection("phase_1").addDocument(data: [
//            "id": id,
//            "title": title,
//            "content": content,
//            "tag": tag,
//            "author_id": ("rayshin_\(uuid)"),
//            "created_time": timeStamp
//        ]) { (error) in
//            if let error = error {
//                print(error)
//            }
//        }// add data to db collection document. set parameters for title, content, tag
    }
    
    func readArticleData() {
        
        db.collection("phase_1").addSnapshotListener { querySnapshot, error in
            guard let snapshot = querySnapshot else {
                print("Error fetching snapshots: \(error!)")
                return
            }
            
            for document in snapshot.documents {
                print(document.data())
            }
            
            snapshot.documentChanges.forEach { diff in /*for diff in snapshot.documentChanges {} */
                                                       
                if (diff.type == .added) {
                    print("================================")
                    print("New Article: \(diff.document.data())")
                }
                if (diff.type == .modified) {
                    print("Modified Article: \(diff.document.data())")
                }
                if (diff.type == .removed) {
                    print("Removed Article: \(diff.document.data())")
                }
            }
        }// read data: use snapshot listener to observe/get realtime updates of db(any changes in DB). data() from add data
    }
    
    
    //search email, if email exits then show alert
    // 寄邀請給對方，對方的friendlist 會有我的資料
    func fetchUserData(email: String) {
        let db = Firestore.firestore()
        
        db.collection("user_data").whereField("email", isEqualTo: email).getDocuments { (querySnapshot, error) in
            if let querySnapshot = querySnapshot {
                if let document = querySnapshot.documents.first {
                    self.confirmAlert(document: document)
//                    print(document.data())
                } else {
                    print("there is no this user")
                }
            }
        }
    }
    
    
    //監聽我自己的document 去檢查有沒有接收到別人的邀請
    func fetchListener() {
        db.collection("user_data").whereField("email", isEqualTo: UserProfile.email).addSnapshotListener { querySnapshot, error in
            guard let snapshot = querySnapshot,
                  let myDocument = snapshot.documents.first,
                  let myFriendList = myDocument["friendList"] as? [[String: Any]] else {
                print("Error fetching snapshots: \(error!)")
                return
            }
            print(myFriendList)
            
            if let idx = myFriendList.firstIndex(where: { ($0["isFriend"] as? Bool) == false }) {
                var newFriendList = myFriendList
                var invitation = myFriendList[idx]
                
                let alert = UIAlertController(title: "New Invitation", message: "\(invitation["name"] as! String) invite u to be a friend", preferredStyle: .alert)
                let agreeAction = UIAlertAction(title: "Agree", style: .default) { _ in
                    invitation["isFriend"] = true
                    newFriendList[idx] = invitation
                    myDocument.reference.updateData([
                        "friendList": newFriendList
                    ])
                    
                    //把自己加到對方的friend list
                    self.db.collection("user_data").whereField("email", isEqualTo: invitation["email"] as! String).getDocuments { snapshot, error in
                        if let document = snapshot?.documents.first,
                            let friendList = document["friendList"] as? [[String: Any]] {
                            var newList = friendList
                            newList.append([
                                "name": UserProfile.name,
                                "email": UserProfile.email,
                                "isFriend": true
                            ])
                            document.reference.updateData(["friendList" : newList])
                        }
                    }
                }
                
                let disagreeAction = UIAlertAction(title: "No", style: .default) { _ in
                    newFriendList.remove(at: idx)
                    myDocument.reference.updateData([
                        "friendList": newFriendList
                    ])
                }
                
                alert.addAction(agreeAction)
                alert.addAction(disagreeAction)
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    
    
    //search user and pop up send invitation alert
    func confirmAlert(document: QueryDocumentSnapshot) {
        let alert = UIAlertController(title: "Add Friend?", message: "Do you want to add to your friend list?", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Yes", style: .default, handler: { _ in
            document.reference.updateData([
                "friendList": [[
                    "name": UserProfile.name,
                    "email": UserProfile.email,
                    "isFriend": false
                ]]
            ])
        })
        
        alert.addAction(okAction)
        present(alert, animated: true, completion: nil)
    }
}

