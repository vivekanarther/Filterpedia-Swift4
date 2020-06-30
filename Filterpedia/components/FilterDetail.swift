//
//  FilterDetail.swift
//  Filterpedia
//
//  Created by Simon Gladman on 29/12/2015.
//  Copyright © 2015 Simon Gladman. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.

//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>

import UIKit

extension FilterDetail: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        selectedImage = info[UIImagePickerControllerOriginalImage] as? UIImage
        let keyWindow = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        if var topController = keyWindow?.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            topController.dismiss(animated: true, completion: nil)
        }
        if (filters.count == 0) {
            self.imageView.image = selectedImage
        } else {
            applyFilter()
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        let keyWindow = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        if var topController = keyWindow?.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            topController.dismiss(animated: true, completion: nil)
        }
    }
}

class FilterDetail: UIView
{
    let rect640x640 = CGRect(x: 0, y: 0, width: 640, height: 640)
    let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
    
    let compositeOverBlackFilter = CompositeOverBlackFilter()
    
    let shapeLayer: CAShapeLayer =
    {
        let layer = CAShapeLayer()
        
        layer.strokeColor = UIColor.lightGray.cgColor
        layer.fillColor = nil
        layer.lineWidth = 0.5
        
        return layer
    }()
    
    let tableView: UITableView =
    {
        let tableView = UITableView(frame: CGRect.zero,
                                    style: UITableViewStyle.plain)
        
        tableView.register(FilterInputItemRenderer.self,
                           forCellReuseIdentifier: "FilterInputItemRenderer")
        
        return tableView
    }()
    
    let scrollView = UIScrollView()
    
    lazy var pickImageBtn: UIButton =
        {
            let btn = UIButton()
            btn.setTitleColor(.black, for: .normal)
            btn.setTitle("Pick Image", for: .normal)
            btn.addTarget(
                self,
                action: #selector(FilterDetail.pickImageTapped),
                for: .touchUpInside)
            
            return btn
    }()
    
    lazy var revertBtn: UIButton =
        {
            let btn = UIButton()
            btn.setTitleColor(.black, for: .normal)
            btn.setTitle("Undo", for: .normal)
            btn.addTarget(
                self,
                action: #selector(FilterDetail.revertTapped),
                for: .touchUpInside)
            
            return btn
    }()
    
    lazy var viewFormulaBtn: UIButton =
        {
            let btn = UIButton()
            btn.setTitleColor(.black, for: .normal)
            btn.setTitle("View Formula", for: .normal)
            btn.addTarget(
                self,
                action: #selector(FilterDetail.viewFormulaTapped),
                for: .touchUpInside)
            
            return btn
    }()
    
    var selectedImage: UIImage?
    
    let histogramDisplay = HistogramDisplay()
    
    var histogramDisplayHidden = true
    {
        didSet
        {
            if !histogramDisplayHidden
            {
                self.histogramDisplay.imageRef = imageView.image?.cgImage
            }
            
            UIView.animate(withDuration: 0.25, animations: {
                self.histogramDisplay.alpha = self.histogramDisplayHidden ? 0 : 1
            })
            
        }
    }
    
    let imageView: UIImageView =
    {
        let imageView = UIImageView()
        
        imageView.backgroundColor = UIColor.black
        
        imageView.layer.borderColor = UIColor.gray.cgColor
        imageView.layer.borderWidth = 1
        
        return imageView
    }()
    
    #if !arch(i386) && !arch(x86_64)
    let ciMetalContext = CIContext(mtlDevice: MTLCreateSystemDefaultDevice()!)
    #else
    let ciMetalContext = CIContext()
    #endif
    
    let ciOpenGLESContext = CIContext()
    
    /// Whether a filter is currently running in the background
    var busy = false
    {
        didSet
        {
            if busy
            {
                activityIndicator.startAnimating()
            }
            else
            {
                activityIndicator.stopAnimating()
            }
        }
    }
    
    var filterName: String?
    {
        didSet
        {
            updateFromFilterName()
        }
    }
    
    fileprivate var currentFilter: CIFilter?
    fileprivate var filters = [CIFilter]()
    
    /// User defined filter parameter values
    fileprivate var filterParameterValues: [String: AnyObject] = [:]
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        tableView.dataSource = self
        tableView.delegate = self
        
        addSubview(tableView)
        
        addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 6.0
        scrollView.delegate = self
        
        histogramDisplay.alpha = histogramDisplayHidden ? 0 : 1
        histogramDisplay.layer.shadowOffset = CGSize(width: 0, height: 0)
        histogramDisplay.layer.shadowOpacity = 0.75
        histogramDisplay.layer.shadowRadius = 5
        addSubview(histogramDisplay)
        
        addSubview(pickImageBtn)
        addSubview(viewFormulaBtn)
        addSubview(revertBtn)
        
        imageView.addSubview(activityIndicator)
        
        layer.addSublayer(shapeLayer)
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func pickImageTapped()
    {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = false
        picker.sourceType = .photoLibrary
        picker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .savedPhotosAlbum)!
        let keyWindow = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        
        if var topController = keyWindow?.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            topController.present(picker, animated: true, completion: nil)
        }
        
    }
    
    @objc func viewFormulaTapped()
    {
        let keyWindow = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        
        if var topController = keyWindow?.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            topController.present(FormulaVC(with: filters), animated: true, completion: nil)
        }
    }
    
    @objc func revertTapped() {
        if (filters.count > 0) {
            filters.removeLast()
        }
        applyFilter()
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func updateFromFilterName()
    {
        guard let filterName = filterName else
        {
            return
        }
        
        if filters.last?.name == filterName {
            currentFilter = filters.last!
        } else {
            currentFilter = CIFilter(name: filterName)
            filters.append(currentFilter!)
        }
        
//        imageView.subviews
//            .filter({ $0 is FilterAttributesDisplayable})
//            .forEach({ $0.removeFromSuperview() })
//
//        if let widget = OverlayWidgets.getOverlayWidgetForFilter(filterName) as? UIView
//        {
//            imageView.addSubview(widget)
//
//            widget.frame = imageView.bounds
//        }
    
        filterParameterValues.removeAll()
        fixFilterParameterValues()
        tableView.reloadData()
        
//        applyFilter()
    }
    
    /// Assign a default image if required and ensure existing
    /// filterParameterValues won't break the new filter.
    func fixFilterParameterValues()
    {
        guard let currentFilter = currentFilter else
        {
            return
        }
        
        let attributes = currentFilter.attributes
        
        
        for inputKey in currentFilter.inputKeys
        {
            if let attribute = attributes[inputKey] as? [String : AnyObject]
            {
                // default image
                if let className = attribute[kCIAttributeClass] as? String, className == "CIImage" && filterParameterValues[inputKey] == nil
                {
                    filterParameterValues[inputKey] = assets.first!.ciImage
                }
                
                // ensure previous values don't exceed kCIAttributeSliderMax for this filter
//                if let maxValue = attribute[kCIAttributeSliderMax] as? Float,
//                    let filterParameterValue = filterParameterValues[inputKey] as? Float, filterParameterValue > maxValue
//                {
                    filterParameterValues[inputKey] = currentFilter.value(forKey: inputKey) as AnyObject?
//                }
//                
//                // ensure vector is correct length
//                if let defaultVector = attribute[kCIAttributeDefault] as? CIVector,
//                    let filterParameterValue = filterParameterValues[inputKey] as? CIVector, defaultVector.count != filterParameterValue.count
//                {
//                    filterParameterValues[inputKey] = defaultVector
//                }
            }
        }
    }
    
    func applyFilter()
    {
        guard let selectedImage = self.selectedImage else
        {
            return
        }
        
        self.busy = true
        
        if let currentFilter = self.currentFilter {
//            imageView.subviews
//                .filter({ $0 is FilterAttributesDisplayable})
//                .forEach({ ($0 as? FilterAttributesDisplayable)?.setFilter(currentFilter) })
//
            for (key, value) in self.filterParameterValues where currentFilter.inputKeys.contains(key)
            {
                currentFilter.setValue(value, forKey: key)
            }
        }
        
        var tempOutput = CIImage(image: selectedImage)
        
        for index in 0..<self.filters.count {
            let filter = self.filters[index]
            var parameters: [String: Any] = [:]
            for keyIndex in 0..<filter.inputKeys.count {
                if (filter.inputKeys[keyIndex] == kCIInputImageKey) {
                    parameters[filter.inputKeys[keyIndex]] = tempOutput
                } else {
                    parameters[filter.inputKeys[keyIndex]] = filter.value(forKey: filter.inputKeys[keyIndex])
                }
            }
            tempOutput = CIFilter(name: filter.name, withInputParameters: parameters)?.outputImage
        }
        let outputImage = tempOutput!
        
        let finalImage: CGImage
        
        let context = self.ciOpenGLESContext
        
        if outputImage.extent.width == 1 || outputImage.extent.height == 1
        {
            // if a filter's output image height or width is 1,
            // (e.g. a reduction filter) stretch to 640x640
            
            let stretch = CIFilter(name: "CIStretchCrop",
                                   withInputParameters: ["inputSize": CIVector(x: 640, y: 640),
                                                         "inputCropAmount": 0,
                                                         "inputCenterStretchAmount": 1,
                                                         kCIInputImageKey: outputImage])!
            
            finalImage = context.createCGImage(stretch.outputImage!,
                                               from: self.rect640x640)!
        }
        else if outputImage.extent.width < 640 || outputImage.extent.height < 640
        {
            // if a filter's output image is smaller than 640x640 (e.g. circular wrap or lenticular
            // halo), composite the output over a black background)
            
            self.compositeOverBlackFilter.setValue(outputImage,
                                                   forKey: kCIInputImageKey)
            
            finalImage = context.createCGImage(self.compositeOverBlackFilter.outputImage!,
                                               from: self.rect640x640)!
        }
        else
        {
            finalImage = context.createCGImage(outputImage,
                                               from: outputImage.extent)!
        }
        self.busy = false
        self.imageView.image = UIImage(ciImage: outputImage)
        
    }
    
    override func layoutSubviews()
    {
        let halfWidth = frame.width * 0.5
        let thirdHeight = frame.height * 0.333
        let twoThirdHeight = frame.height * 0.666
        
        scrollView.frame = CGRect(x: halfWidth - thirdHeight,
                                  y: 0,
                                  width: twoThirdHeight,
                                  height: twoThirdHeight)
        
        imageView.frame = CGRect(x: 0,
                                 y: 0,
                                 width: scrollView.frame.width,
                                 height: scrollView.frame.height)
        
        tableView.frame = CGRect(x: 0,
                                 y: twoThirdHeight,
                                 width: frame.width,
                                 height: thirdHeight)
        
        histogramDisplay.frame = CGRect(
            x: 0,
            y: thirdHeight,
            width: frame.width,
            height: thirdHeight).insetBy(dx: 5, dy: 5)
        
        pickImageBtn.frame = CGRect(
            x: frame.width - pickImageBtn.intrinsicContentSize.width,
            y: 0,
            width: pickImageBtn.intrinsicContentSize.width,
            height: pickImageBtn.intrinsicContentSize.height)
        
        viewFormulaBtn.frame = CGRect(
            x: frame.width - viewFormulaBtn.intrinsicContentSize.width,
            y: pickImageBtn.frame.maxY + 20,
            width: viewFormulaBtn.intrinsicContentSize.width,
            height: viewFormulaBtn.intrinsicContentSize.height)
        
        revertBtn.frame = CGRect(
        x: frame.width - revertBtn.intrinsicContentSize.width,
        y: viewFormulaBtn.frame.maxY + 20,
        width: revertBtn.intrinsicContentSize.width,
        height: revertBtn.intrinsicContentSize.height)

        
        tableView.separatorStyle = UITableViewCellSeparatorStyle.none
        
        activityIndicator.frame = imageView.bounds
        
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: frame.height))
        
        shapeLayer.path = path.cgPath
    }
}

// MARK: UITableViewDelegate extension

extension FilterDetail: UITableViewDelegate
{
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return 85
    }
}

// MARK: UITableViewDataSource extension

extension FilterDetail: UITableViewDataSource
{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return currentFilter?.inputKeys.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FilterInputItemRenderer",
                                                 for: indexPath) as! FilterInputItemRenderer
        
        if let inputKey = currentFilter?.inputKeys[indexPath.row],
            let attribute = currentFilter?.attributes[inputKey] as? [String : AnyObject]
        {
            cell.detail = (inputKey: inputKey,
                           attribute: attribute,
                           filterParameterValues: filterParameterValues)
        }
        
        cell.delegate = self
        
        return cell
    }
}

// MARK: FilterInputItemRendererDelegate extension

extension FilterDetail: FilterInputItemRendererDelegate
{
    func filterInputItemRenderer(_ filterInputItemRenderer: FilterInputItemRenderer, didChangeValue: AnyObject?, forKey: String?)
    {
        if let key = forKey, let value = didChangeValue, key != kCIInputImageKey
        {
            filterParameterValues[key] = value
            if filters.count == 0 || (filters.count > 0 && (filters.last?.name != currentFilter!.name)) {
                filters.append(currentFilter!)
            }
            applyFilter()
            
        }
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool
    {
        return false
    }
}

class FormulaVC: UITableViewController {
    let filters: [CIFilter]
    init(with filters: [CIFilter]) {
        self.filters = filters
        super.init(style: .plain)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = filters[indexPath.row].description
        cell.textLabel?.numberOfLines = 0
        return cell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filters.count
    }
}
