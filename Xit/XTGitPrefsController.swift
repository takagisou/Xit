import Cocoa

class XTGitPrefsController: NSViewController, PreferencesSaver
{
  @IBOutlet weak var userNameField: NSTextField!
  @IBOutlet weak var userEmailField: NSTextField!
  @IBOutlet weak var fetchTagsCheckbox: NSButton!
  @IBOutlet weak var fetchPruneCheckbox: NSButton!
  
  let config = GTConfiguration.default()
  
  struct PrefKey {
    static let FetchTags = "FetchTags"
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    guard let config = config
    else {
      let allControls = [userNameField,
                         userEmailField,
                         fetchTagsCheckbox,
                         fetchPruneCheckbox] as [NSControl]
      
      allControls.forEach { $0.isEnabled = false }
      return
    }
    
    userNameField.stringValue = config.string(forKey: "user.name") ?? ""
    userEmailField.stringValue = config.string(forKey: "user.email") ?? ""
    
    fetchPruneCheckbox.boolValue = config.bool(forKey: "fetch.prune")
    fetchTagsCheckbox.boolValue = UserDefaults.standard
        .bool(forKey: PrefKey.FetchTags)
    
    NotificationCenter.default.addObserver(
        forName: NSNotification.Name.NSWindowDidResignKey,
        object: self.view.window,
        queue: nil) { (_) in
      self.savePreferences()
    }
  }
  
  func savePreferences()
  {
    config?.setString(userNameField.stringValue, forKey: "user.name")
    config?.setString(userEmailField.stringValue, forKey: "user.email")
    
    config?.setBool(fetchPruneCheckbox.boolValue, forKey: "fetch.prune")
    UserDefaults.standard.set(fetchTagsCheckbox.boolValue,
                              forKey: PrefKey.FetchTags)
  }
}
