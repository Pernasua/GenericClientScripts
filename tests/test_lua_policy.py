from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from lua_policy import violations


class LuaPolicyTest(unittest.TestCase):
    def test_rejects_legacy_fields_in_nested_actions_and_helpers(self):
        for source in (
            "gc.await { action = { type = 'walk.to' }, breaks = false }",
            "gc.await({ action = { type = 'walk.to' }, ['breaks'] = true })",
            r'gc.phase("bank", { ["break\115"] = false })',
            "equipment.equip(1, 'Wear', {breaks = false})",
            "gc.walk.to {destination = target, interrupt_on_dialogue = true}",
        ):
            with self.subTest(source=source):
                self.assertEqual(1, len(violations(source)))

    def test_accepts_policies_and_ignores_comments_and_unrelated_text(self):
        source = '''
        -- gc.await { breaks = false }
        local example = [==[ breaks = true, interrupt_on_dialogue = true ]==]
        gc.activity('combat', { breaks = true })
        local policy = { breaks = false, cursor_release = 'none' }
        local urgent_policy = { breaks = false, fidget = 'none' }
        policy.breaks = false
        policy['breaks'] = false
        gc.await { action = { type = 'combat.attack' }, policy = policy }
        gc.await { action = { type = 'walk.to' }, policy = { ['breaks'] = false } }
        gc.intent('talk', function() gc.await { action = { type = 'dialogue.continue' } } end)
        '''
        self.assertEqual([], violations(source))

    def test_detects_combat_activity_mismatch_from_the_action_table(self):
        self.assertEqual(1, len(violations('''
        gc.activity('skilling')
        local action = { type = 'combat.set_style', style = 0 }
        gc.await { action = action }
        ''')))
        self.assertEqual([], violations("gc.activity('skilling'); local message='combat.attack'"))

    def test_catalog_source_uses_the_current_behavior_api(self):
        failures = []
        for path in sorted((ROOT / "scripts").rglob("*.lua")):
            for line, message in violations(path.read_text()):
                failures.append(f"{path.relative_to(ROOT)}:{line}: {message}")
        self.assertEqual([], failures, "\n".join(failures))


if __name__ == "__main__":
    unittest.main()
