#import "XTTest.h"
#import "XTTest.h"
#import "XTRepository.h"
#import "XTRepository+Commands.h"
#import <ObjectiveGit/ObjectiveGit.h>
#import "Xit-Swift.h"

@interface XTSideBarDataSorceTests : XTTest
{
  NSOutlineView *outlineView;
  XTSideBarDataSource *sbds;
}

- (id)groupItemForIndex:(NSUInteger)index;

@end

@interface MockTextField : NSObject
@property(strong) NSString *stringValue;
@property(strong) NSFont *font;
@end

@interface MockSidebarOutlineView : NSObject
- (id)makeViewWithIdentifier:(NSString *)identifier owner:(id)owner;
- (id)parentForItem:(id)item;
@end

@implementation XTSideBarDataSorceTests

- (void)setUp
{
  [super setUp];
  sbds = [[XTSideBarDataSource alloc] init];
  outlineView = [[NSOutlineView alloc] init];
  sbds.outline = outlineView;
}

- (id)groupItemForIndex:(NSUInteger)index
{
  // Add one to skip the staging item
  return [sbds outlineView:outlineView child:index ofItem:nil];
}

- (void)testStashes
{
  XCTAssertTrue([self writeTextToFile1:@"second text"], @"");
  XCTAssertTrue([self.repository saveStash:@"s1" includeUntracked:NO], @"");
  XCTAssertTrue([self writeTextToFile1:@"third text"], @"");
  XCTAssertTrue([self.repository saveStash:@"s2" includeUntracked:NO], @"");

  [sbds setRepo:self.repository];
  [sbds reload];
  [self waitForRepoQueue];

  id stashes = [self groupItemForIndex:XTGroupIndexStashes];
  XCTAssertNotNil(stashes);

  NSInteger stashCount = [sbds outlineView:outlineView numberOfChildrenOfItem:stashes];
  XCTAssertEqual(stashCount, 2L, @"");
}

- (void)testRemotes
{
  [self makeRemoteRepo];

  XCTAssertTrue([self.repository checkout:@"master" error:NULL]);
  XCTAssertTrue([self.repository createBranch:@"b1"]);
  XCTAssertTrue([self.repository addRemote:@"origin"
                                   withUrl:self.remoteRepoPath]);

  NSError *error = nil;
  NSArray *configArgs = @[ @"config", @"receive.denyCurrentBranch", @"ignore" ];

  [self.remoteRepository executeGitWithArgs:configArgs writes:NO error:&error];
  if (error != nil) {
    XCTFail(@"Ignore denyCurrentBranch");
    return;
  }

  if (![self.repository push:@"origin"]) {
    XCTFail(@"push origin");
    return;
  }

  MockSidebarOutlineView *sov = [[MockSidebarOutlineView alloc] init];
  
  [sbds setRepo:self.repository];
  [self waitForRepoQueue];

  id remotes = [self groupItemForIndex:XTGroupIndexRemotes];
  XCTAssertNotNil(remotes);

  const NSInteger remoteCount = [sbds outlineView:outlineView numberOfChildrenOfItem:remotes];
  XCTAssertEqual(remoteCount, 1);

  // BRANCHES
  id remote = [sbds outlineView:outlineView child:0 ofItem:remotes];
  NSTableCellView *remoteView =
      (NSTableCellView *)[sbds outlineView:(NSOutlineView *)sov
                        viewForTableColumn:nil
                                      item:remote];
  NSString *rName = remoteView.textField.stringValue;
  XCTAssertEqualObjects(rName, @"origin");

  const NSInteger branchCount = [sbds outlineView:outlineView numberOfChildrenOfItem:remote];
  XCTAssertEqual(branchCount, 2);

  bool branchB1Found = false;
  bool branchMasterFound = false;
  
  for (int n = 0; n < branchCount; n++) {
    id branch = [sbds outlineView:outlineView child:n ofItem:remote];
    BOOL isExpandable = [sbds outlineView:outlineView isItemExpandable:branch];
    XCTAssertTrue(isExpandable == NO, @"Branches must be no Expandable");

    NSTableCellView *branchView =
        (NSTableCellView *)[sbds outlineView:(NSOutlineView *)sov
                          viewForTableColumn:nil
                                        item:branch];
    NSString *bName = branchView.textField.stringValue;
    if ([bName isEqualToString:@"master"]) {
      branchMasterFound = YES;
    } else if ([bName isEqualToString:@"b1"]) {
      branchB1Found = YES;
    }
  }
  XCTAssertTrue(branchMasterFound, @"Branch 'master' Not found");
  XCTAssertTrue(branchB1Found, @"Branch 'b1' Not found");
}

- (void)testSubmodules
{
  NSString *tempPath = NSTemporaryDirectory();
  XTRepository *repo1 = [self createRepo:
      [tempPath stringByAppendingPathComponent:@"repo1"]];
  XTRepository *repo2 = [self createRepo:
      [tempPath stringByAppendingPathComponent:@"repo2"]];
  XCTAssertNotNil(repo1, @"");
  XCTAssertNotNil(repo2, @"");

  XCTAssertTrue([self commitNewTextFile:@"file1"
                               content:@"blah"
                          inRepository:repo1]);
  [self waitForRepository:repo1];
  XCTAssertTrue([self commitNewTextFile:@"file2"
                               content:@"fffff"
                          inRepository:repo2]);

  [self waitForRepository:repo2];
  XCTAssertTrue([self.repository addSubmoduleAtPath:@"sub1"
                                          urlOrPath:@"../repo1"
                                              error:NULL]);
  XCTAssertTrue([self.repository addSubmoduleAtPath:@"sub2"
                                          urlOrPath:@"../repo2"
                                              error:NULL]);

  [sbds setRepo:self.repository];
  [self waitForRepoQueue];

  id subs = [self groupItemForIndex:XTGroupIndexSubmodules];
  XCTAssertNotNil(subs);

  const NSInteger subCount = [sbds outlineView:outlineView numberOfChildrenOfItem:subs];
  XCTAssertEqual(subCount, 2L);

  for (int i = 0; i < subCount; ++i) {
    XTSubmoduleItem *sub = [sbds outlineView:outlineView child:i ofItem:subs];
    NSString *name = [NSString stringWithFormat:@"sub%d", i+1];
    NSString *url = [NSString stringWithFormat:@"../repo%d", i+1];

    XCTAssertNotNil(sub.submodule);
    XCTAssertEqualObjects(sub.submodule.name, name, @"");
    XCTAssertEqualObjects(sub.submodule.URLString, url);
  }
}

- (void)testGroupItems
{
  if (![self.repository createBranch:@"b1"]) {
    XCTFail(@"Create Branch 'b1'");
  }

  [sbds setRepo:self.repository];
  [sbds reload];

  // Start at 1 to skip "Staging"
  for (NSInteger i = 1; i < [sbds outlineView:outlineView numberOfChildrenOfItem:nil];
       ++i) {
    id root = [sbds outlineView:outlineView child:i ofItem:nil];
    XCTAssertTrue([sbds outlineView:outlineView isGroupItem:root],
                 @"item %ld should be group", (long)i);
  }
}

@end


@implementation MockTextField

@synthesize stringValue;

- (void)setFormatter:(id)formatter {}
- (void)setTarget:(id)target {}
- (void)setAction:(SEL)action {}
- (void)setEditable:(BOOL)editable {}
- (void)setSelectable:(BOOL)selectable {}

@end


@implementation MockSidebarOutlineView

- (id)makeViewWithIdentifier:(NSString *)identifier owner:(id)owner
{
  XTSidebarTableCellView *view =
      [[XTSidebarTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 185, 20)];
  NSTextField *label =
      [[NSTextField alloc] initWithFrame:NSMakeRect(26, 3, 163, 17)];
  NSImageView *image =
      [[NSImageView alloc] initWithFrame:NSMakeRect(5, 2, 16, 16)];
  NSImageView *statusImage =
      [[NSImageView alloc] initWithFrame:NSMakeRect(171, 2, 16, 16)];
  NSButton *statusButton =
      [[NSButton alloc] initWithFrame:NSMakeRect(171, 2, 16, 16)];
  NSButton *statusText =
      [NSButton buttonWithTitle:@"10" target:nil action:nil];
  
  [view addSubview:label];
  [view addSubview:image];
  [view addSubview:statusImage];
  [view addSubview:statusButton];
  [view addSubview:statusText];
  view.textField = label;
  view.imageView = image;
  view.statusImage = statusImage;
  view.statusButton = statusButton;
  view.statusText = statusText;
  return view;
}

- (id)parentForItem:(id)item
{
  return nil;
}

@end
