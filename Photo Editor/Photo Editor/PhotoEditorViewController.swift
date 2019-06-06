//
//  ViewController.swift
//  Photo Editor
//
//  Created by Mohamed Hamed on 4/23/17.
//  Copyright © 2017 Mohamed Hamed. All rights reserved.
//

import UIKit

public final class PhotoEditorViewController: UIViewController {
    var selectedView: UIView?
     var inputToolbar: UIView!
     var textView: GrowingTextView!
     var textViewBottomConstraint: NSLayoutConstraint!
     var keepAspectRatio = false {
        didSet {
            cropView?.keepAspectRatio = keepAspectRatio
        }
    }
     var cropAspectRatio: CGFloat = 0.0 {
        didSet {
            cropView?.cropAspectRatio = cropAspectRatio
        }
    }
     var cropRect = CGRect.zero {
        didSet {
            adjustCropRect()
        }
    }
     var imageCropRect = CGRect.zero {
        didSet {
            cropView?.imageCropRect = imageCropRect
        }
    }
     var rotationEnabled = false {
        didSet {
            cropView?.rotationGestureRecognizer.isEnabled = rotationEnabled
        }
    }
     var rotationTransform: CGAffineTransform {
        return cropView!.rotation
    }
     var zoomedCropRect: CGRect {
        return cropView!.zoomedCropRect()
    }
    
    @IBOutlet weak var undoButton: UIButton!
    @IBOutlet weak var cropBaseView: UIView!
    @IBOutlet weak var cropView: CropView!
    /** holding the 2 imageViews original image and drawing & stickers */
    @IBOutlet weak var canvasView: UIView!
    //To hold the image
    @IBOutlet var  imageView: UIImageView!
    @IBOutlet weak var imageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewWidthConstraint: NSLayoutConstraint!
    //To hold the drawings and stickers
    @IBOutlet weak var canvasImageView: UIImageView!

    @IBOutlet weak var topToolbar: UIView!
    @IBOutlet weak var bottomToolbar: UIView!

    @IBOutlet weak var topGradient: UIView!
    @IBOutlet weak var bottomGradient: UIView!
    
    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var deleteView: UIView!
    @IBOutlet weak var colorsCollectionView: UICollectionView!
    @IBOutlet weak var colorPickerView: UIView!
    @IBOutlet weak var colorPickerViewBottomConstraint: NSLayoutConstraint!
    
    //Controls
    @IBOutlet weak var cropButton: UIButton!
    @IBOutlet weak var stickerButton: UIButton!
    @IBOutlet weak var drawButton: UIButton!
    @IBOutlet weak var textButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var clearButton: UIButton!
    
    public var image: UIImage?
    /**
     Array of Stickers -UIImage- that the user will choose from
     */
    public var stickers : [UIImage] = []
    /**
     Array of Colors that will show while drawing or typing
     */
    public var colors  : [UIColor] = []
    
    public var photoEditorDelegate: PhotoEditorDelegate?
    var colorsCollectionViewDelegate: ColorsCollectionViewDelegate!
    
    // list of controls to be hidden
    public var hiddenControls : [control] = []
    
    var stickersVCIsVisible = false
    var drawColor: UIColor = UIColor.black
    var textColor: UIColor = UIColor.white
    var isDrawing: Bool = false
    var lastPoint: CGPoint!
    var swiped = false
    var lastPanPoint: CGPoint?
    var lastTextViewTransform: CGAffineTransform?
    var lastTextViewTransCenter: CGPoint?
    var lastTextViewFont:UIFont?
    var activeTextView: UITextView?
    var imageViewToPan: UIImageView?
    var isTyping: Bool = false
    
    var stickersViewController: StickersViewController!
    var strCaption = ""

    //Register Custom font before we load XIB
    public override func loadView() {
        registerFont()
        super.loadView()
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(PhotoEditorViewController.rotated), name: UIDevice.orientationDidChangeNotification, object: nil)

        self.undoButton.isHidden = true
//        if #available(iOS 10.0, *) {
//            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { (timer) in
//                self.undoButton.isHidden = self.canvasImageView.subviews.count == 0
//            }
//        } else {
//            // Fallback on earlier versions
//        }
        
        self.setImageView(image: image!)
        self.cropBaseView.isHidden = true
        deleteView.layer.cornerRadius = deleteView.bounds.height / 2
        deleteView.layer.borderWidth = 2.0
        deleteView.layer.borderColor = UIColor.white.cgColor
        deleteView.clipsToBounds = true
        
        let edgePan = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(screenEdgeSwiped(_:)))
        edgePan.edges = .bottom
        edgePan.delegate = self
        self.view.addGestureRecognizer(edgePan)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow(notification:)),
                                               name: UIWindow.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)),
                                               name: UIWindow.keyboardWillHideNotification, object: nil)
        
        NotificationCenter.default.addObserver(self,selector: #selector(keyboardWillChangeFrame(_:)),
                                               name: UIWindow.keyboardWillChangeFrameNotification, object: nil)
        
        
        configureCollectionView()
        stickersViewController = StickersViewController(nibName: "StickersViewController", bundle: Bundle(for: StickersViewController.self))
        hideControls()
        let gesture = UITapGestureRecognizer(target: self, action: #selector(PhotoEditorViewController.cropSingleTap))
        gesture.numberOfTapsRequired = 1
        gesture.numberOfTouchesRequired = 1
        self.cropBaseView.addGestureRecognizer(gesture)
        let colorSlider = ColorSlider(orientation: .vertical, previewSide: .left)
        colorSlider.previewView?.isHidden = true
        colorSlider.addTarget(self, action: #selector(changedColor(slider:)), for: .valueChanged)
        colorPickerView.addSubview(colorSlider)
        colorSlider.frame = self.colorPickerView.bounds
        
        self.textButton.layer.cornerRadius = self.textButton.frame.width / 2
        self.textButton.layer.masksToBounds = true
        self.drawButton.layer.cornerRadius = self.drawButton.frame.width / 2
        self.drawButton.layer.masksToBounds = true
        
        
        let gestureDrawing = UITapGestureRecognizer(target: self, action: #selector(PhotoEditorViewController.drwaSingleTap))
        gestureDrawing.numberOfTapsRequired = 2
        self.view.addGestureRecognizer(gestureDrawing)
        initializeCustomItems(self.view)
        
        let gestureDrawingKeyBoardResign = UITapGestureRecognizer(target: self, action: #selector(PhotoEditorViewController.resignKeyBoard))
        gestureDrawingKeyBoardResign.numberOfTapsRequired = 1
        self.canvasView.addGestureRecognizer(gestureDrawingKeyBoardResign)
        
        let defaultGesture = UITapGestureRecognizer(target: self, action: #selector(PhotoEditorViewController.noAction))
        gestureDrawingKeyBoardResign.numberOfTapsRequired = 1
        self.cropView.addGestureRecognizer(defaultGesture)
        
    }
    
    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppUtility.lockOrientation(.portrait)
    }
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        AppUtility.lockOrientation(.all)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func rotated() {
//        if let image = originalImage {
//            self.setImageView(image: image)
//        }
        if UIDevice.current.orientation.isLandscape {
            print("Landscape")
        } else {
            print("Portrait")
        }
    }
    @objc func resignKeyBoard() {
        self.view.endEditing(true)
    }
    @objc func noAction() {
    }
    @objc func drwaSingleTap() {
        if self.isDrawing {
            self.doneButtonTapped(UIButton())
        }
    }
    
    @objc func changedColor(slider: ColorSlider) {
        drawColor = slider.color
        activeTextView?.textColor = slider.color
        textColor = slider.color
        self.textButton.setBackgroundColor(color: slider.color, forState: .selected)
        self.drawButton.setBackgroundColor(color: slider.color, forState: .selected)
        
    }
    @objc func cropSingleTap() {
        self.cropBaseView.isHidden = true
        self.hideToolbar(hide: false)
        self.textView.isHidden = false
    }
    
    func configureCollectionView() {
        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 30, height: 30)
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        colorsCollectionView.collectionViewLayout = layout
        colorsCollectionViewDelegate = ColorsCollectionViewDelegate()
        colorsCollectionViewDelegate.colorDelegate = self
        if !colors.isEmpty {
            colorsCollectionViewDelegate.colors = colors
        }
        colorsCollectionView.delegate = colorsCollectionViewDelegate
        colorsCollectionView.dataSource = colorsCollectionViewDelegate
        
        colorsCollectionView.register(
            UINib(nibName: "ColorCollectionViewCell", bundle: Bundle(for: ColorCollectionViewCell.self)),
            forCellWithReuseIdentifier: "ColorCollectionViewCell")
    }
//    var originalImage: UIImage?
    func setImageView(image: UIImage) {
        self.canvasImageView.image = nil
//        if let data = image.jpegData(compressionQuality: 1.0), originalImage == nil {
//            originalImage = UIImage(data: data)
//        }
        if UIScreen.main.bounds.width > UIScreen.main.bounds.height {
            imageView.image = image
            let size = image.suitableSize(heightLimit: CGFloat.minimum(UIScreen.main.bounds.height, image.size.height))
            imageViewHeightConstraint.constant = (size?.height)!
            imageViewWidthConstraint.constant = (size?.width)!
            self.view.layoutIfNeeded()
        } else {
            imageView.image = image
            let size = image.suitableSize(widthLimit: CGFloat.minimum(UIScreen.main.bounds.width, image.size.width))
            imageViewHeightConstraint.constant = (size?.height)!
            imageViewWidthConstraint.constant = (size?.width)!
            self.view.layoutIfNeeded()
        }
//=======
//
//        imageView.image = image
//        let size = image.suitableSize(widthLimit: CGFloat.minimum(UIScreen.main.bounds.width, image.size.width))
//        imageViewHeightConstraint.constant = (size?.height)!
//        imageViewWidthConstraint.constant = (size?.width)!
//        self.view.layoutIfNeeded()
//        return
////        if let data = image.jpegData(compressionQuality: 1.0), originalImage == nil {
////            originalImage = UIImage(data: data)
////        }
////        if UIScreen.main.bounds.width > UIScreen.main.bounds.height {
////            imageView.image = image
////            let size = image.suitableSize(heightLimit: CGFloat.minimum(UIScreen.main.bounds.height, image.size.height))
////            imageViewHeightConstraint.constant = (size?.height)!
////            imageViewWidthConstraint.constant = (size?.width)!
////            self.view.layoutIfNeeded()
////        } else {
////            imageView.image = image
////            let size = image.suitableSize(widthLimit: CGFloat.minimum(UIScreen.main.bounds.width, image.size.width))
////            imageViewHeightConstraint.constant = (size?.height)!
////            imageViewWidthConstraint.constant = (size?.width)!
////            self.view.layoutIfNeeded()
////        }
//>>>>>>> 1526106a0a51c7fcab2b68376fd303dcef55f395
    }
    
    

    
    func hideToolbar(hide: Bool) {
//        if isTyping && !hide {
//          topToolbar.isHidden = true
//        } else {
//           topToolbar.isHidden = hide
//        }
        topGradient.isHidden = hide
        bottomToolbar.isHidden = true
        bottomGradient.isHidden = hide
        self.inputToolbar.isHidden = hide
    }
    
//    @IBAction func btnFilterClicked(_ sender: UIButton) {
//        let image = self.canvasView.toImage()
//        let vc = SHViewController(image: image)
//        vc.delegate = self
//        present(vc, animated: true, completion: nil)
//    }
//    deinit {
//        NotificationCenter.default.removeObserver(self)
//    }
}

extension PhotoEditorViewController: ColorDelegate {
    func didSelectColor(color: UIColor) {
        if isDrawing {
            self.drawColor = color
        } else if activeTextView != nil {
            activeTextView?.textColor = color
            textColor = color
        }
    }
}

//extension PhotoEditorViewController: SHViewControllerDelegate {
//    public func shViewControllerImageDidFilter(image: UIImage) {
//        for viewSub in self.canvasImageView.subviews {
//            viewSub.removeFromSuperview()
//        }
//
//        self.setImageView(image: image)
//
//    }
//
//    public func shViewControllerDidCancel() {
//    }
//
//
//
//
//
//
//}



//struct AppUtility {
//
//    static func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
//
//        if let delegate = UIApplication.shared.delegate as? AppDelegate {
//            delegate.orientationLock = orientation
//        }
//    }
//
//    /// OPTIONAL Added method to adjust lock and rotate to the desired orientation
//    static func lockOrientation(_ orientation: UIInterfaceOrientationMask, andRotateTo rotateOrientation:UIInterfaceOrientation) {
//
//        self.lockOrientation(orientation)
//
//        UIDevice.current.setValue(rotateOrientation.rawValue, forKey: "orientation")
//        UINavigationController.attemptRotationToDeviceOrientation()
//    }
//
//}
