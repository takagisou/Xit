import Cocoa


public protocol Commit: OIDObject, CustomStringConvertible
{
  var sha: String? { get }
  var parentOIDs: [OID] { get }
  
  var message: String? { get }
  
  var authorSig: Signature? { get }
  var committerSig: Signature? { get }
  
  var authorName: String? { get }
  var authorEmail: String? { get }
  var authorDate: Date? { get }
  var committerName: String? { get }
  var committerEmail: String? { get }
  var commitDate: Date { get }
  var email: String? { get }
  
  var tree: Tree? { get }
}

extension Commit
{
  var authorName: String? { return authorSig?.name }
  var authorEmail: String? { return authorSig?.email }
  var authorDate: Date? { return authorSig?.when }
  var committerName: String? { return committerSig?.name }
  var committerEmail: String? { return committerSig?.email }
  var commitDate: Date { return committerSig?.when ?? Date() }
}

extension Commit
{
  public var parentSHAs: [String]
  {
    return parentOIDs.flatMap { $0.sha }
  }
  
  public var messageSummary: String
  {
    guard let message = message
    else { return "" }
    
    return message.range(of: "\n").map {
      String(message[..<$0.lowerBound])
    } ?? message
  }

  public var description: String
  { return "\(sha?.firstSix() ?? "-")" }
}


public class XTCommit: Commit
{
  let gtCommit: GTCommit

  public private(set) lazy var sha: String? = self.gtCommit.sha
  public private(set) lazy var oid: OID =
      GitOID(oid: self.gtCommit.oid!.git_oid().pointee)
  public private(set) lazy var parentOIDs: [OID] =
      XTCommit.calculateParentOIDs(self.gtCommit.git_commit())
  
  public var message: String?
  { return gtCommit.message }
  
  public var messageSummary: String
  { return gtCommit.messageSummary }
  
  public var authorSig: Signature?
  {
    guard let sig = git_commit_author(gtCommit.git_commit())
    else { return nil }
    
    return Signature(gitSignature: sig.pointee)
  }
  
  public var authorName: String?
  { return gtCommit.author?.name }
  
  public var authorEmail: String?
  { return gtCommit.author?.email }
  
  public var authorDate: Date?
  { return gtCommit.author?.time }
  
  public var committerSig: Signature?
  {
    guard let sig = git_commit_committer(gtCommit.git_commit())
    else { return nil }
    
    return Signature(gitSignature: sig.pointee)
  }
  
  public var committerName: String?
  { return gtCommit.committer?.name }
  
  public var committerEmail: String?
  { return gtCommit.committer?.email }
  
  public var commitDate: Date
  { return gtCommit.commitDate }
  
  public var email: String?
  { return gtCommit.author?.email }

  public var tree: Tree?
  {
    var tree: OpaquePointer?
    let result = git_commit_tree(&tree, gtCommit.git_commit())
    guard result == 0,
          let finalTree = tree
    else { return nil }
    
    return GitTree(tree: finalTree)
  }

  init?(gitCommit: OpaquePointer, repository: OpaquePointer)
  {
    guard let repository = GTRepository(gitRepository: repository),
          let commit = GTCommit(obj: gitCommit, in: repository)
    else { return nil }
    
    self.gtCommit = commit
  }
  
  init(commit: GTCommit)
  {
    self.gtCommit = commit
  }

  convenience init?(oid: OID, repository: XTRepository)
  {
    guard let oid = oid as? GitOID
    else { return nil }
    var gitCommit: OpaquePointer?  // git_commit isn't imported
    let result = git_commit_lookup(&gitCommit,
                                   repository.gtRepo.git_repository(),
                                   oid.unsafeOID())
  
    guard result == 0,
          let commit = GTCommit(obj: gitCommit!, in: repository.gtRepo)
    else { return nil }
    
    self.init(commit: commit)
  }
  
  convenience init?(sha: String, repository: XTRepository)
  {
    guard let oid = GitOID(sha: sha)
    else { return nil }
    
    self.init(oid: oid, repository: repository)
  }
  
  convenience init?(ref: String, repository: XTRepository)
  {
    let gitRefPtr = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    guard git_reference_lookup(gitRefPtr,
                               repository.gtRepo.git_repository(),
                               ref) == 0,
          let gitRef = gitRefPtr.pointee
    else { return nil }
    
    let gitObjectPtr = UnsafeMutablePointer<OpaquePointer?>.allocate(capacity: 1)
    guard git_reference_peel(gitObjectPtr, gitRef, GIT_OBJ_COMMIT) == 0,
          let gitObject = gitObjectPtr.pointee,
          let commit = GTCommit(obj: gitObject, in: repository.gtRepo)
    else { return nil }
    
    self.init(commit: commit)
  }
  
  /// Returns a list of all files in the commit's tree, with paths relative
  /// to the root.
  func allFiles() -> [String]
  {
    guard let tree = tree as? GitTree
    else { return [] }
    
    var result = [String]()
    
    tree.walkEntries {
      (entry, root) in
      result.append(root.appending(pathComponent: entry.name))
    }
    return result
  }
  
  private static func calculateParentOIDs(_ rawCommit: OpaquePointer) -> [GitOID]
  {
    var result = [GitOID]()
    
    for index in 0..<git_commit_parentcount(rawCommit) {
      let parentID = git_commit_parent_id(rawCommit, index)
      guard parentID != nil
      else { continue }
      
      result.append(GitOID(oidPtr: parentID!))
    }
    return result
  }
}

public func == (a: XTCommit, b: XTCommit) -> Bool
{
  return (a.oid as! GitOID) == (b.oid as! GitOID)
}
