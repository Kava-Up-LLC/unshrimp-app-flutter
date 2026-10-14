import json, os, subprocess, pathlib, sys
# Style JSON path comes from argv[1] or $STYLE_JSON, defaulting to ./prompts.json.
style_src = pathlib.Path(
    sys.argv[1] if len(sys.argv) > 1 else os.environ.get('STYLE_JSON', 'prompts.json')
)
style = json.loads(style_src.read_text())['style']
pose = ('a stocky man with a thick torso and sturdy legs bending over in a standing forward fold, seen from the side in a three-quarter view: both legs straight with the feet apart '
        'on the floor, the hips up, the torso folded forward and down with a rounded back, the head hanging down between the arms with a blank face, no eyes, '
        'both arms hanging straight down toward the floor with open hands, fingers pointing down, fingertips next to the white sneakers')
mflux = str(pathlib.Path.home() / '.venvs/mflux/bin/mflux-generate')
for seed, steps, strength in [(11, 12, 0.25), (11, 8, 0.3)]:
    out = f'h6_s{seed}_{steps}_{strength}.png'
    print('>>', out, flush=True)
    subprocess.run([mflux, '--model', 'dhairyashil/FLUX.1-schnell-mflux-4bit', '--base-model', 'schnell', '--steps', str(steps),
                    '--width', '1024', '--height', '1024', '--seed', str(seed), '--image-path', 'guide6.png', '--image-strength', str(strength),
                    '--prompt', f'{style} The character is {pose}.', '--output', out], check=False)
print('done')
