//
//  ViewController.swift
//  Quiet4Swift
//
//  Created by guhui on 2022/1/25.
//

import UIKit
import RxSwift
import RxCocoa
import QuietModemKit

class ViewController: UIViewController {
    
    static var rx: QMFrameReceiver?
    var quietDisposeClosure: (()->Void)!
    @IBOutlet var msgLabel: UILabel!
    @IBOutlet var btnSend: UIButton!
    @IBOutlet var btnRecord: UIButton!
    @IBOutlet var txtSend: UITextField!
    @IBOutlet var pickerConfig: UIPickerView!
    var disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initControls()
    }
    
    func initControls(){
        btnSend.rx.tap.subscribe(onNext: {
            _ in
            //print("send")
            let txConf = QMTransmitterConfig.init(key: self.getConfigKey())
            let tx = QMFrameTransmitter.init(config: txConf)
            tx?.send( self.txtSend.text?.data(using: .utf8) )
            tx?.close()
        })
        .disposed(by: disposeBag)
        
        
        btnRecord.rx.tap.flatMap{
            self.checkRecordOrStop()
        }
        .flatMap{ _ in
            self.requestRecordPermission()//.debug("requestRecordPermission sub")
        }
        .flatMapLatest{_ in
            self.beginReceive()//.debug("beginReceive sub")
        }
        .subscribe(onNext: {
            [weak msgLabel] receive in
            print("receive: \(receive)")
            msgLabel?.text = "receive: \(receive)"
        },onCompleted:{
            print("--complete--")
        }).disposed(by: disposeBag)
        
        
        Observable.just(["audible","ultrasonic-fsk","ultrasonic-fsk-fast"])
            .bind(to: pickerConfig.rx.itemTitles){
                _,item in
                return item
            }
            .disposed(by: disposeBag)
    }
    
    func getConfigKey() -> String {
        let selectRow = pickerConfig.selectedRow(inComponent: 0)
        let selectItem: String = try! pickerConfig.rx.model(at: IndexPath(row: selectRow, section: 0))
        return selectItem
    }
    
    func checkRecordOrStop() -> Maybe<Bool>{
        if ViewController.rx == nil{
            return Maybe.just(true)
        }else{
            ViewController.rx?.close()
            ViewController.rx = nil
            self.btnRecord.setTitle("Record", for: .normal)
            if let quietAction = quietDisposeClosure{
                quietAction()
                quietDisposeClosure = nil
            }
            return Maybe.empty()
        }
    }
    
    func requestRecordPermission() -> Maybe<Bool> {
        return Maybe<Bool>.create{ observer in
            AVAudioSession.sharedInstance().requestRecordPermission{
                granted in
                if( granted ){
                    observer(.success(true))
                }else{
                    observer(.completed)
                }
            }
            return Disposables.create{
                print("dispose requestRecordPermission")
            }
        }
    }
    
    func beginReceive() -> Observable<String>{
        self.btnRecord.setTitle("Stop", for: .normal)
        //print( "Rx Resources count: \(RxSwift.Resources.total)")
        return Observable.create { observer in
            let rxConf = QMReceiverConfig.init(key: self.getConfigKey())
            ViewController.rx = QMFrameReceiver.init(config: rxConf)
            self.quietDisposeClosure = {
                observer.onCompleted()
            }
            ViewController.rx?.setReceiveCallback{
                data in
                let message = String(data: data!, encoding: .utf8)
                if let message = message{
                    observer.on(.next(message))
                }
            }
            return Disposables.create{
                print("dispose beginReceive")
            }
        }
        
    }
}

