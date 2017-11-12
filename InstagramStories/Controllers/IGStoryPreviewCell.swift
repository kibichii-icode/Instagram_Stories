//
//  IGStoryPreviewCell.swift
//  InstagramStories
//
//  Created by Boominadha Prakash on 06/09/17.
//  Copyright © 2017 Dash. All rights reserved.
//

import UIKit

protocol StoryPreviewProtocol:class {
    func didCompletePreview()
    func didTapCloseButton()
}

fileprivate let snapViewTagIndicator:Int = 8

final class IGStoryPreviewCell: UICollectionViewCell,UIScrollViewDelegate {
    
    //MARK: - iVars
    public weak var delegate:StoryPreviewProtocol? {
        didSet { storyHeaderView.delegate = self }
    }
    
    private let scrollview: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.showsHorizontalScrollIndicator = false
        sv.isScrollEnabled = false
        return sv
    }()
    
    private lazy var storyHeaderView: IGStoryPreviewHeaderView = {
        let v = IGStoryPreviewHeaderView.init(frame: CGRect(x:0,y:0,width:frame.width,height:80))
        return v
    }()
    private lazy var longPress_gesture: UILongPressGestureRecognizer = {
        let lp = UILongPressGestureRecognizer.init(target: self, action: #selector(didLongPress(_:)))
        lp.minimumPressDuration = 0.2
        return lp
    }()
    
    public var isCompletelyVisible:Bool = false{
        didSet{
            if scrollview.subviews.count > 0 {
                let imageView = scrollview.subviews.filter{v in v.tag == snapIndex + snapViewTagIndicator}.first as? UIImageView
                if imageView?.image != nil && isCompletelyVisible == true{
                    gearupTheProgressors()
                }
            }
        }
    }
    
    public var snapIndex:Int = 0 {
        didSet {
            if snapIndex < story?.snapsCount ?? 0 {
                if let snap = story?.snaps?[snapIndex] {
                    if let url = snap.url {
                        let snapView = createSnapView()
                        startRequest(snapView: snapView, with: url)
                    }
                    storyHeaderView.lastUpdatedLabel.text = snap.lastUpdated
                }
            }
        }
    }
    public var story:IGStory? {
        didSet {
            storyHeaderView.story = story
            if let picture = story?.user?.picture {
                storyHeaderView.snaperImageView.setImage(url: picture)
            }
            if let count = story?.snaps?.count {
                scrollview.contentSize = CGSize(width:IGScreen.width * CGFloat(count), height:IGScreen.height)
            }
        }
    }
    
    //MARK: - Overriden functions
    override init(frame: CGRect) {
        super.init(frame: frame)
        scrollview.frame = bounds
        loadUIElements()
        installLayoutConstraints()
    }
    override func prepareForReuse() {
        super.prepareForReuse()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    //MARK: - Private functions
    private func loadUIElements(){
        scrollview.delegate = self
        scrollview.isPagingEnabled = true
        addSubview(scrollview)
        addSubview(storyHeaderView)
        scrollview.addGestureRecognizer(longPress_gesture)
    }
    private func installLayoutConstraints(){
        //Setting constraints for scrollview
        NSLayoutConstraint.activate([scrollview.leftAnchor.constraint(equalTo: contentView.leftAnchor),
        scrollview.rightAnchor.constraint(equalTo: contentView.rightAnchor),
        scrollview.topAnchor.constraint(equalTo: contentView.topAnchor),
        scrollview.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)])
    }
    private func createSnapView()->UIImageView {
        let previousSnapIndex = snapIndex - 1
        let x_value = (snapIndex == 0) ? 0 : scrollview.subviews[previousSnapIndex].frame.maxX
        let snapView = UIImageView.init(frame: CGRect(x: x_value, y: 0, width: scrollview.frame.width, height: scrollview.frame.height))
        snapView.tag = snapIndex + snapViewTagIndicator
        scrollview.addSubview(snapView)
        return snapView
    }
    
    private func startRequest(snapView:UIImageView,with url:String) {
        snapView.setImage(url: url, style: .squared, completion: { (result, error) in
            if let error = error {
                debugPrint(error.localizedDescription)
            }else {
                if self.isCompletelyVisible {
                    self.gearupTheProgressors()
                }
            }
        })
    }
    
    @objc private func didLongPress(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began || sender.state == .ended {
            let v = getProgressView(with: snapIndex)
            if sender.state == .began {
                v?.pause()
            }else {
                v?.resume()
            }
        }
    }
    
    @objc private func didEnterForeground() {
        if let indicatorView = getProgressIndicatorView(with: snapIndex),
            let pv = getProgressView(with: snapIndex) {
            pv.start(with: 5.0, width: indicatorView.frame.width, completion: {
                self.didCompleteProgress()
            })
        }
    }
    
    @objc private func didCompleteProgress() {
        let n = snapIndex + 1
        if let count = story?.snapsCount {
            if n < count {
                //Move to next snap
                let x = n.toFloat() * frame.width
                let offset = CGPoint(x:x,y:0)
                scrollview.setContentOffset(offset, animated: false)
                story?.lastPlayedSnapIndex = snapIndex
                snapIndex = n
            }else {
                delegate?.didCompletePreview()
            }
        }
    }
    
    private func getProgressView(with index:Int)->IGSnapProgressView? {
        let progressView = storyHeaderView.getProgressView()
        if progressView.subviews.count>0 {
            return progressView.subviews.filter({v in v.tag == index+progressViewTag}).first as? IGSnapProgressView
        }
        return nil
    }
    
    private func getProgressIndicatorView(with index:Int)->UIView? {
        let progressView = storyHeaderView.getProgressView()
        if progressView.subviews.count>0 {
            return progressView.subviews.filter({v in v.tag == index+progressIndicatorViewTag}).first
        }else{
            return nil
        }
    }
    private func fillupLastPlayedSnaps(_ sIndex:Int) {
        //Coz, we are ignoring the first.snap
        if sIndex != 0 {
            for i in 0..<sIndex {
                if let holderView = self.getProgressIndicatorView(with: i),
                    let progressView = self.getProgressView(with: i){
                    progressView.frame.size.width = holderView.frame.width
                }
            }
        }
    }
    private func gearupTheProgressors() {
        if let holderView = getProgressIndicatorView(with: snapIndex),
            let progressView = getProgressView(with: snapIndex){
            progressView.start(with: 5.0, width: holderView.frame.width, completion: {
                self.didCompleteProgress()
            })
        }
    }
    
    //MARK: - Public functions
    public func willDisplayAtZerothIndex() {
        isCompletelyVisible = true
        willDisplayCell(with: 0)
    }
    
    public func willDisplayCell(with sIndex:Int) {
        //Todo:Make sure to move filling part and creating at one place
        storyHeaderView.createSnapProgressors()
        fillupLastPlayedSnaps(sIndex)
        snapIndex = sIndex
        NotificationCenter.default.addObserver(self, selector: #selector(self.didEnterForeground), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
    }
    
    public func didEndDisplayingCell() {
        isCompletelyVisible = false
        if let lastPlayedIndex = story?.lastPlayedSnapIndex {
            let imageView = scrollview.subviews[lastPlayedIndex] as? UIImageView
            imageView?.removeFromSuperview()
            self.storyHeaderView.clearTheProgressorViews(for: lastPlayedIndex)
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    public func willBeginDragging(with index:Int) {
        getProgressView(with: index)?.pause()
    }
    public func didEndDecelerating(with index:Int) {
        getProgressView(with: index)?.resume()
    }
    
    
}
//MARK: - Extension/StoryPreviewHeaderProtocol
extension IGStoryPreviewCell:StoryPreviewHeaderProtocol {
    func didTapCloseButton() {
        delegate?.didTapCloseButton()
    }
}
