import Foundation

protocol BuildStatusClient: class
{
  func buildStatusUpdated(branch: String, buildType: String)
}

class BuildStatusCache: TeamCityAccessor
{
  // This typealias resolves ambiguity for the compiler
  typealias BranchStatuses = [String: TeamCityAPI.Build] // Branch to build

  weak var remoteMgr: RemoteManagement!
  // Eventually use BranchListing instead of XTRepository once the
  // associatedtypes are gone.
  weak var branchLister: XTRepository?
  var statuses = [String: BranchStatuses]() // Build type to branch builds
  private var clients = [WeakClientRef]()
  
  class WeakClientRef
  {
    weak var client: BuildStatusClient?
    
    init(client: BuildStatusClient)
    {
      self.client = client
    }
  }
  
  init(branchLister: XTRepository, remoteMgr: RemoteManagement)
  {
    self.remoteMgr = remoteMgr
    self.branchLister = branchLister
  }
  
  func add(client: BuildStatusClient)
  {
    if !clients.contains(where: { $0.client === client }) {
      clients.append(WeakClientRef(client: client))
    }
  }
  
  func remove(client: BuildStatusClient)
  {
    clients.index(where: { $0.client === client })
           .map { _ = clients.remove(at: $0) }
  }
  
  func refresh()
  {
    guard let localBranches = branchLister?.localBranches()
    else { return }
    
    statuses.removeAll()
    for local in localBranches {
      guard let tracked = local.trackingBranch,
            let remoteName = tracked.remoteName,
            let (api, buildTypes) = matchTeamCity(remoteName)
      else { continue }
      
      let fullBranchName = local.name
      
      for buildType in buildTypes {
        guard let branchName = api.displayName(forBranch: fullBranchName,
                                               buildType: buildType)
        else { continue }
        
        let statusResource = api.buildStatus(branchName, buildType: buildType)
        
        statusResource.useData(owner: self) {
          (data) in
          guard let xml = data.content as? XMLDocument,
                let firstBuildElement = xml.rootElement()?.children?.first
                                        as? XMLElement,
                let build = TeamCityAPI.Build(element: firstBuildElement)
          else { return }
          
          NSLog("\(buildType)/\(branchName): \(build.status?.rawValue ?? "?")")
          var buildTypeStatuses = self.statuses[buildType] ??
                                  BranchStatuses()
          
          buildTypeStatuses[branchName] = build
          self.statuses[buildType] = buildTypeStatuses
          for ref in self.clients {
            ref.client?.buildStatusUpdated(branch: branchName,
                                              buildType: buildType)
          }
        }
      }
    }
  }
}
