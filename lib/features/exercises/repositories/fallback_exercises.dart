import '../models/exercise.dart';

/// Local copy of the CMS `exercises` content, used when the CMS can't be
/// reached. Keep it in sync with the CMS entries. Office stretches and their
/// images come from the RepDB free-tier dataset in `assets/dataset/`.
const fallbackExercises = [
  Exercise(
    zone: 'neck',
    title: 'Neck Side Stretch',
    steps:
        'Sit or stand tall with your shoulders relaxed, then tilt your head so one ear drops toward that shoulder.',
    assetPath: 'assets/dataset/media/neck-side-stretch.gif',
  ),
  Exercise(
    zone: 'neck',
    title: 'Isometric Neck Lateral Flexion',
    steps:
        'Sit or stand tall. Place the palm of one hand against the side of the head, above the ear, then press the head into the hand while resisting equally with the hand, the head does not move.',
    assetPath: 'assets/dataset/media/isometric-neck-side.gif',
  ),
  Exercise(
    zone: 'neck',
    title: 'Chin Tuck Hold',
    steps:
        'Stand or sit tall with your shoulders relaxed, then pull your chin straight back, creating a double chin.',
    assetPath: 'assets/dataset/media/chin-tuck-hold.gif',
  ),
  Exercise(
    zone: 'shoulders',
    title: 'Cross-Body Shoulder Stretch',
    steps:
        'Stand tall and bring one straight arm across your chest, then hook your other forearm under it.',
    assetPath: 'assets/dataset/media/cross-body-shoulder-stretch.gif',
  ),
  Exercise(
    zone: 'shoulders',
    title: 'Doorway Chest Stretch',
    steps:
        'Stand tall and raise your arms into a goalpost position, then bend your elbows ninety degrees, forearms vertical.',
    assetPath: 'assets/dataset/media/doorway-chest-stretch.gif',
  ),
  Exercise(
    zone: 'shoulders',
    title: 'Overhead Triceps Stretch',
    steps:
        'Raise one arm overhead and bend the elbow, then let your hand drop down behind your head.',
    assetPath: 'assets/dataset/media/overhead-triceps-stretch.gif',
  ),
  Exercise(
    zone: 'lower_back',
    title: 'Standing Side Bend',
    steps:
        'Stand with feet hip-width and reach both arms overhead, then clasp your hands and lengthen up tall.',
    assetPath: 'assets/dataset/media/standing-side-bend.gif',
  ),
  Exercise(
    zone: 'lower_back',
    title: 'Standing Side Bend Flow',
    steps:
        'Stand with the feet hip-width apart and reach both arms overhead, then bend the trunk to one side, keeping both feet planted and the hips level.',
    assetPath: 'assets/dataset/media/standing-side-bend-flow.gif',
  ),
  Exercise(
    zone: 'lower_back',
    title: 'Pilates Roll Down',
    steps:
        'Stand tall with the feet hip-width apart and the arms hanging at the sides, then drop the chin to the chest and start rolling down one vertebra at a time.',
    assetPath: 'assets/dataset/media/pilates-roll-down.gif',
  ),
  Exercise(
    zone: 'none',
    title: 'Mountain Pose',
    steps:
        'Stand with the feet hip-width apart and spread the weight evenly across both feet, then engage the thighs lightly and let the tailbone drop so the pelvis is neutral.',
    assetPath: 'assets/dataset/media/mountain-pose.gif',
  ),
  Exercise(
    zone: 'none',
    title: 'Standing Forward Fold',
    steps:
        'Stand tall with your feet hip-width apart and legs straight, then hinge at your hips and fold your torso down toward the floor.',
    assetPath: 'assets/dataset/media/standing-forward-fold.gif',
  ),
  Exercise(
    zone: 'none',
    title: 'Standing Quad Stretch',
    steps:
        'Stand on one leg, holding a wall for balance if needed, then bend the other knee and grab that ankle behind you.',
    assetPath: 'assets/dataset/media/standing-quad-stretch.gif',
  ),
  Exercise(
    zone: 'none',
    title: 'Standing Calf Stretch',
    steps:
        'Step one foot back into a staggered stance, then keep the back leg straight and the heel pressed down.',
    assetPath: 'assets/dataset/media/standing-calf-stretch.gif',
  ),
];
