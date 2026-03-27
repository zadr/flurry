#import "SettingsViewController.h"
#import "FlurryPresetManager.h"

static NSArray *colorModeNames(void) {
    static NSArray *names = nil;
    if (!names) {
        names = [@[@"Red", @"Magenta", @"Blue", @"Cyan", @"Green", @"Yellow",
                   @"Slow Cyclic", @"Cyclic", @"Tiedye", @"Rainbow",
                   @"White", @"Multi", @"Dark"] retain];
    }
    return names;
}

// Section indices
enum {
    SectionRandomPreset = 0,
    SectionPresets,
    SectionFlurries,
    SectionCount
};

@implementation SettingsViewController {
    UITableView *_tableView;
    NSInteger _selectedFlurryIndex;
}

- (void)dealloc {
    [_presetManager release];
    [_tableView release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];

    _selectedFlurryIndex = 0;

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:40],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-40],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:100],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-100],
    ]];
}

#pragma mark - Dismissal

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    for (UIPress *press in presses) {
        if (press.type == UIPressTypeMenu) {
            [_delegate settingsDidChangeWithRandomise:_randomisePreset];
            [self dismissViewControllerAnimated:YES completion:nil];
            return;
        }
    }
    [super pressesBegan:presses withEvent:event];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return SectionCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case SectionRandomPreset: return @"Options";
        case SectionPresets: return @"Presets";
        case SectionFlurries: return @"Flurry Settings";
        default: return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case SectionRandomPreset:
            return 1;
        case SectionPresets:
            return [[_presetManager presets] count];
        case SectionFlurries: {
            FlurryPreset *preset = [_presetManager activePreset];
            // For each flurry: color mode, stream count, thickness, speed = 4 rows per flurry
            return [[preset flurries] count] * 4;
        }
        default: return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"] autorelease];
    }

    // Reset
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.text = @"";
    cell.detailTextLabel.text = @"";

    switch (indexPath.section) {
        case SectionRandomPreset: {
            cell.textLabel.text = @"Random Preset";
            cell.detailTextLabel.text = _randomisePreset ? @"On" : @"Off";
            break;
        }
        case SectionPresets: {
            FlurryPreset *preset = [[_presetManager presets] objectAtIndex:indexPath.row];
            cell.textLabel.text = [preset name];
            if (indexPath.row == [_presetManager activePresetIndex]) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }
            break;
        }
        case SectionFlurries: {
            FlurryPreset *preset = [_presetManager activePreset];
            NSInteger flurryIndex = indexPath.row / 4;
            NSInteger param = indexPath.row % 4;
            Flurry *flurry = [[preset flurries] objectAtIndex:flurryIndex];
            global_info_t *fInfo = [flurry info];

            NSString *prefix = [NSString stringWithFormat:@"Flurry %ld", (long)flurryIndex + 1];

            switch (param) {
                case 0: {
                    cell.textLabel.text = [NSString stringWithFormat:@"%@ Color", prefix];
                    NSArray *names = colorModeNames();
                    NSUInteger colorIdx = (NSUInteger)fInfo->currentColorMode;
                    cell.detailTextLabel.text = colorIdx < [names count] ? [names objectAtIndex:colorIdx] : @"Unknown";
                    break;
                }
                case 1:
                    cell.textLabel.text = [NSString stringWithFormat:@"%@ Streams", prefix];
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", fInfo->numStreams];
                    break;
                case 2:
                    cell.textLabel.text = [NSString stringWithFormat:@"%@ Thickness", prefix];
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.0f", sqrt(fInfo->streamExpansion)];
                    break;
                case 3:
                    cell.textLabel.text = [NSString stringWithFormat:@"%@ Speed", prefix];
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f", fInfo->star->rotSpeed];
                    break;
            }
            break;
        }
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    switch (indexPath.section) {
        case SectionRandomPreset: {
            _randomisePreset = !_randomisePreset;
            [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            break;
        }
        case SectionPresets: {
            [_presetManager setActivePresetIndex:indexPath.row];
            [tableView reloadData];
            break;
        }
        case SectionFlurries: {
            FlurryPreset *preset = [_presetManager activePreset];
            NSInteger flurryIndex = indexPath.row / 4;
            NSInteger param = indexPath.row % 4;
            Flurry *flurry = [[preset flurries] objectAtIndex:flurryIndex];
            global_info_t *fInfo = [flurry info];

            switch (param) {
                case 0: {
                    // Cycle color mode
                    int nextMode = (fInfo->currentColorMode + 1) % 13;
                    fInfo->currentColorMode = (ColorModes)nextMode;
                    break;
                }
                case 1: {
                    // Cycle stream count 1-12
                    int next = fInfo->numStreams + 1;
                    if (next > 12) next = 1;
                    fInfo->numStreams = next;
                    break;
                }
                case 2: {
                    // Cycle thickness: 1, 5, 10, 50, 100, 200, 500, 1000
                    float sqrtThick = sqrt(fInfo->streamExpansion);
                    float steps[] = {1, 5, 10, 50, 100, 200, 500, 1000};
                    int numSteps = 8;
                    int nextIdx = 0;
                    for (int i = 0; i < numSteps; i++) {
                        if (sqrtThick >= steps[i]) nextIdx = i + 1;
                    }
                    if (nextIdx >= numSteps) nextIdx = 0;
                    float val = steps[nextIdx];
                    fInfo->streamExpansion = val * val;
                    break;
                }
                case 3: {
                    // Cycle speed: 0, 0.2, 0.5, 0.8, 1.0, 1.5, 2.0, 3.0
                    float speeds[] = {0.0, 0.2, 0.5, 0.8, 1.0, 1.5, 2.0, 3.0};
                    int numSpeeds = 8;
                    int nextIdx = 0;
                    for (int i = 0; i < numSpeeds; i++) {
                        if (fInfo->star->rotSpeed >= speeds[i]) nextIdx = i + 1;
                    }
                    if (nextIdx >= numSpeeds) nextIdx = 0;
                    fInfo->star->rotSpeed = speeds[nextIdx];
                    break;
                }
            }
            [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            break;
        }
    }
}

@end
