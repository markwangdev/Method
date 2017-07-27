//
//  RecordingViewController.swift
//  Method
//
//  Created by Mark Wang on 7/19/17.
//  Copyright © 2017 MarkWang. All rights reserved.
//

import UIKit
import Speech
import AVFoundation
import FirebaseStorage
import FirebaseDatabase

class RecordingViewController: UIViewController, SFSpeechRecognizerDelegate, AVAudioRecorderDelegate {

    // MARK: Properties
    
    //Speech Recognition
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    //Audio
    private var recordingSession: AVAudioSession!
    private var audioRecorder: AVAudioRecorder!
    var soundFileURL:URL!
    var currentFilename: String!
    var currentRecording: Recording!
    
    //Video 
    private var videoSession: AVCaptureSession! = AVCaptureSession()
    //private var captureDevice: AVCaptureDevice
    
    // Timer
    var seconds = 60
    var timer = Timer()
    var isTimerRunning = false
    
    var timer2 = Timer()
    var recordingTime = 0.0
    
    //UI elements
    @IBOutlet weak var transcriptTextView: UITextView!

    @IBOutlet weak var recordButton: UIButton!
    
    @IBOutlet weak var listButton: UIButton!
    
    @IBOutlet weak var timerLabel: UILabel!
    
    @IBOutlet weak var videoView: UIView!
    
    @IBOutlet weak var countingTimerLabel: UILabel!
    
    // MARK: RecordingVIewViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let previewLayer = AVCaptureVideoPreviewLayer.init(session: videoSession)
        previewLayer?.frame = videoView.bounds
        //videoView.addSubview(previewLayer)
        //testing
        //self.view.backgroundColor = UIColor.darkGray
        // Disable the record buttons until authorization has been granted.
        recordButton.isEnabled = false
        self.timerLabel.text = "\(seconds)s"
    }

    override public func viewDidAppear(_ animated: Bool) {
        
        //Speech Recognition
        speechRecognizer.delegate = self
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            /*
             The callback may not be called on the main thread. Add an
             operation to the main queue to update the record button's state.
             */
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.recordButton.isEnabled = true
                    
                case .denied:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("User denied access to speech recognition", for: .disabled)
                    
                case .restricted:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition restricted on this device", for: .disabled)
                    
                case .notDetermined:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                }
            }
        }
        
    }
    
    override func didReceiveMemoryWarning(){
        super.didReceiveMemoryWarning()
    }
    
    func loadRecordingUI() {
        //recordButton = UIButton(frame: CGRect(x: 64, y: 64, width: 128, height: 64))
        //recordButton.setTitle("Tap to Record", for: .normal)
        //recordButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: UIFontTextStyle.title1)
        //recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        //view.addSubview(recordButton)
    }
    
    func runTimer(){
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: (#selector(RecordingViewController.updateTimer)), userInfo: nil, repeats: true)
    }
    
    //second timer
    func runTimer2(){
        timer2 = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: (#selector(RecordingViewController.updateTimer2)), userInfo: nil, repeats: true)
    }
    
    func updateTimer(){
        if seconds > 0 {
            seconds -= 1
            timerLabel.text = "\(seconds)s"
            
            /*
            recordingTime = audioRecorder.currentTime
            countingTimerLabel.text = "\(recordingTime)s"
            */
        } else{
            print("stopping")
            
            timer.invalidate()
            seconds = 60
            timerLabel.text = "\(seconds)s"
            recordingTime = 0.0
            countingTimerLabel.text = "\(recordingTime)s"
            audioEngine.stop()
            audioRecorder.stop()
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            recordButton.setTitle("Stopping", for: .disabled)
            self.savingAlert()
        }
    }
    
    func updateTimer2(){
        recordingTime = audioRecorder.currentTime
        countingTimerLabel.text = "\(recordingTime)s"
    }
    private func startRecording() throws {
        
        // Cancel the previous task if it's running.
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
            self.audioRecorder = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSessionCategoryRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let inputNode = audioEngine.inputNode else { fatalError("Audio engine has no input node") }
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }
        
        // Configure request so that results are returned before audio recording is finished
        recognitionRequest.shouldReportPartialResults = true
        
        // A recognition task represents a speech recognition session.
        // We keep a reference to the task so that it can be cancelled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                self.transcriptTextView.text = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.recordButton.isEnabled = true
                self.recordButton.setTitle("Start Recording", for: [])
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
     
        let format = DateFormatter()
        format.dateFormat="yyyy-MM-dd-HH-mm-ss"
        currentFilename = "recording-\(format.string(from: Date())).m4a"
        soundFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(currentFilename)

        let recordSettings:[String : Any] = [
            AVFormatIDKey:             kAudioFormatAppleLossless,
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue,
            AVEncoderBitRateKey :      32000,
            AVNumberOfChannelsKey:     2,
            AVSampleRateKey :          44100.0
        ]
        
        audioRecorder = try AVAudioRecorder(url: soundFileURL, settings: recordSettings)
        audioRecorder.delegate = self
        
        audioEngine.prepare()
        
        audioRecorder.record()
        try audioEngine.start()
        transcriptTextView.text = "(Go ahead, I'm listening)"
    }
    
    func removeFile(){
        do{
            try FileManager.default.removeItem(atPath: NSTemporaryDirectory().appending(self.currentFilename))

        } catch{
            print(error)
        }
    }
    
    func savingAlert(){
        
        
        let alert = UIAlertController(title: "Recording Done", message: "Do you want to save this recording?", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction(UIAlertAction(title: "Yes", style: UIAlertActionStyle.default, handler: { action in
        
            let path = NSTemporaryDirectory().appending(self.currentFilename)
    
            guard let audioData = FileManager.default.contents(atPath: path) else{
                return
            }
            
            
            let transcriptText = self.transcriptTextView.text
            
            
            RecordService.create(audioData: audioData, transcriptText: transcriptText!, title: self.currentFilename, time: self.recordingTime)
           
            self.removeFile()
            
            
        }))
        
        alert.addAction(UIAlertAction(title: "No", style: UIAlertActionStyle.cancel, handler: { action in
            self.removeFile()
        }))
        
        self.present(alert, animated: true, completion: nil)
        listButton.isEnabled = true
    }
    // MARK: SFSpeechRecognizerDelegate
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
            recordButton.setTitle("Start Recording", for: [])
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle("Recognition not available", for: .disabled)
        }
    }
    
    
    // MARK: Interface Builder actions
    
    @IBAction func recordButtonTapped(_ sender: UIButton) {
        
        if audioEngine.isRunning {
            timer.invalidate()
            timer2.invalidate()
            audioEngine.stop()
            audioRecorder.stop()
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            recordButton.setTitle("Stopping", for: .disabled)
            
            self.seconds = 60
            self.timerLabel.text = "\(self.seconds)s"
            recordingTime = 0.0
            countingTimerLabel.text = "\(recordingTime)s"
            self.savingAlert()
        } else {
            try! startRecording()
            listButton.isEnabled = false
            runTimer()
            runTimer2()
            recordButton.setTitle("Stop recording", for: [])
        }
        
    }
    
    @IBAction func listButtonTapped(_ sender: UIButton) {
        
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        let listPage = storyboard.instantiateViewController(withIdentifier: "recordsListViewController") as? RecordsListViewController
        self.present(listPage!, animated: true, completion: nil)
    }
    
}

