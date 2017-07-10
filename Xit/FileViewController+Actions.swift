import Foundation

// MARK: NSUserInterfaceValidations
extension FileViewController: NSUserInterfaceValidations
{
  func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool
  {
    guard let action = item.action
      else { return false }
    
    switch action {
    case #selector(self.revert(_:)):
      guard let change = selectedChange()
        else { return false }
      
      switch change.unstagedChange {
      case .unmodified,  // No changes to revert
      .untracked:   // Nothing to revert to
        return false
      default:
        return true
      }
      
    case #selector(self.showWhitespaceChanges(_:)):
      return validateWhitespaceMenuItem(item, whitespace: .showAll)
    case #selector(self.ignoreEOLWhitespace(_:)):
      return validateWhitespaceMenuItem(item, whitespace: .ignoreEOL)
    case #selector(self.ignoreAllWhitespace(_:)):
      return validateWhitespaceMenuItem(item, whitespace: .ignoreAll)
      
    case #selector(self.tabWidth2(_:)):
      return validateTabMenuItem(item, width: 2)
    case #selector(self.tabWidth4(_:)):
      return validateTabMenuItem(item, width: 4)
    case #selector(self.tabWidth6(_:)):
      return validateTabMenuItem(item, width: 6)
    case #selector(self.tabWidth8(_:)):
      return validateTabMenuItem(item, width: 8)
      
    case #selector(self.context0(_:)):
      return validateContextLinesMenuItem(item, context: 0)
    case #selector(self.context3(_:)):
      return validateContextLinesMenuItem(item, context: 3)
    case #selector(self.context6(_:)):
      return validateContextLinesMenuItem(item, context: 6)
    case #selector(self.context12(_:)):
      return validateContextLinesMenuItem(item, context: 12)
    case #selector(self.context25(_:)):
      return validateContextLinesMenuItem(item, context: 25)
      
    default:
      return true
    }
  }
}

// MARK: Validation
extension FileViewController
{
  func validateWhitespaceMenuItem(_ item: AnyObject,
                                  whitespace: WhitespaceSetting) -> Bool
  {
    let menuItem = item as? NSMenuItem
    guard let wsController = contentController as? WhitespaceVariable
      else {
        menuItem?.state = NSOffState
        return false
    }
    
    menuItem?.state = (wsController.whitespace == whitespace) ? NSOnState
      : NSOffState
    return true
  }
  
  func validateTabMenuItem(_ item: AnyObject, width: UInt) -> Bool
  {
    let menuItem = item as? NSMenuItem
    guard let tabController = contentController as? TabWidthVariable
      else {
        menuItem?.state = NSOffState
        return false
    }
    
    menuItem?.state = (tabController.tabWidth == width) ? NSOnState : NSOffState
    return true
  }
  
  func validateContextLinesMenuItem(_ item: AnyObject, context: UInt) -> Bool
  {
    let menuItem = item as? NSMenuItem
    guard let contextController = contentController as? ContextVariable
      else {
        menuItem?.state = NSOffState
        return false
    }
    
    menuItem?.state = (contextController.contextLines == context) ? NSOnState
      : NSOffState
    return true
  }
}

// MARK: Actions
extension FileViewController
{
  @IBAction func changeStageView(_ sender: Any?)
  {
    guard let segmentedControl = sender as? NSSegmentedControl
    else { return }
    
    showingStaged = segmentedControl.selectedSegment == 1
  }

  @IBAction func stageClicked(_ sender: Any?)
  {
    guard let button = sender as? NSButton
    else { return }
  
    click(button: button, staging: true)
  }
  
  @IBAction func unstageClicked(_ sender: Any?)
  {
    guard let button = sender as? NSButton
    else { return }
    
    click(button: button, staging: false)
  }

  @IBAction func changeFileListView(_: Any?)
  {
    let newDS = (viewSelector.selectedSegment == 0 ? fileChangeDS : fileTreeDS)
                as FileListDataSource & NSOutlineViewDataSource
    let columnID = newDS.hierarchical ? ColumnID.main : ColumnID.hidden
    
    fileListOutline.outlineTableColumn =
        fileListOutline.tableColumn(withIdentifier: columnID)
    fileListOutline.delegate = self
    fileListOutline.dataSource = newDS
    if newDS.outlineView!(fileListOutline, numberOfChildrenOfItem: nil) == 0 {
      newDS.reload()
    }
    else {
      fileListOutline.reloadData()
    }
  }
  
  @IBAction func changeContentView(_ sender: Any?)
  {
    guard let segmentedControl = sender as? NSSegmentedControl
    else { return }
    
    let selection = segmentedControl.selectedSegment
    
    previewTabView.selectTabViewItem(withIdentifier: TabID.allIDs[selection])
    contentController = contentControllers[selection]
    loadSelectedPreview()
  }

  @IBAction func stageAll(_: Any?)
  {
    try? repo?.stageAllFiles()
    showingStaged = true
  }
  
  @IBAction func unstageAll(_: Any?)
  {
    try? repo?.unstageAllFiles()
    showingStaged = false
  }

  @IBAction func stageSegmentClicked(_ sender: AnyObject?)
  {
    guard let segmentControl = sender as? NSSegmentedControl,
          let segment = StagingSegment(rawValue: segmentControl.selectedSegment)
    else { return }
    
    switch segment {
      case .unstageAll:
        unstageAll(sender)
      case .stageAll:
        stageAll(sender)
      case .revert:
        revert(sender)
    }
  }
  
  @IBAction func showIgnored(_: Any?)
  {
  }

  @IBAction func revert(_: AnyObject?)
  {
    guard let change = selectedChange()
    else { return }
    
    revert(path: change.path)
  }
  
  @IBAction func showWhitespaceChanges(_ sender: Any?)
  {
    setWhitespace(.showAll)
  }
  
  @IBAction func ignoreEOLWhitespace(_ sender: Any?)
  {
    setWhitespace(.ignoreEOL)
  }
  
  @IBAction func ignoreAllWhitespace(_ sender: Any?)
  {
    setWhitespace(.ignoreAll)
  }
  
  @IBAction func tabWidth2(_ sender: Any?)
  {
    setTabWidth(2)
  }
  
  @IBAction func tabWidth4(_ sender: Any?)
  {
    setTabWidth(4)
  }
  
  @IBAction func tabWidth6(_ sender: Any?)
  {
    setTabWidth(6)
  }
  
  @IBAction func tabWidth8(_ sender: Any?)
  {
    setTabWidth(8)
  }
  
  @IBAction func context0(_ sender: Any?)
  {
    setContext(0)
  }
  
  @IBAction func context3(_ sender: Any?)
  {
    setContext(3)
  }
  
  @IBAction func context6(_ sender: Any?)
  {
    setContext(6)
  }
  
  @IBAction func context12(_ sender: Any?)
  {
    setContext(12)
  }
  
  @IBAction func context25(_ sender: Any?)
  {
    setContext(25)
  }
}
