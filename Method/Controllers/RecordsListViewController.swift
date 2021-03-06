//
//  RecordsListViewController.swift
//  Method
//
//  Created by Mark Wang on 7/19/17.
//  Copyright © 2017 MarkWang. All rights reserved.
//

import Foundation
import UIKit

class RecordsListViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var recordButton: UIButton!
    
    var recordings = [Recording]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.dataSource = self
        
        configureTableView()

        reloadList()
        
        /*
        let record1 = Recording(fileUrlString: "dfjkldf")
        record1.title = "Blah"
        recordings.append(record1)
 */
    }
    
    func configureTableView() {
        // remove separators for empty cells
        tableView.tableFooterView = UIView()
        // remove separators from cells
        tableView.separatorStyle = .none
    }
    
    override func didReceiveMemoryWarning(){
        super.didReceiveMemoryWarning()
    }
    
    func reloadList(){
        UserService.posts(for: User.current) { (recordings) in
            self.recordings = recordings
            self.tableView.reloadData()
        }
    }
    @IBAction func recordButtonTapped(_ sender: Any) {

        dismiss(animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let identifier = segue.identifier {
            if identifier == "showMedia" {
                print("Table view cell tapped")
                
                // 1
                let indexPath = tableView.indexPathForSelectedRow!
                // 2
                let record = recordings[indexPath.row]
                // 3
                let mediaPlayerViewController = segue.destination
                as! MediaPlayerViewController
                
                mediaPlayerViewController.record = record
                
            }
        }
    }
   
}

extension RecordsListViewController: UITableViewDataSource{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recordings.count
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        
        let cell = tableView.dequeueReusableCell(withIdentifier: "audioTableViewCell", for: indexPath) as! RecordedAudioTableViewCell
        
        let row = indexPath.row
        
        let recording = recordings[row]
      
        cell.audioNameLabel.text = recording.title
        cell.audioDateLabel.text = recording.getDateString()
       
        return cell
    }
}
