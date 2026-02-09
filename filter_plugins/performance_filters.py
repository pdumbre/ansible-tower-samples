#!/usr/bin/env python3
"""
Custom Ansible filters for Lenovo IMM performance settings
Implements the getApplicableSettings logic from NodesImmSetup.groovy
"""

class FilterModule(object):
    """Custom filters for performance settings selection"""

    def filters(self):
        return {
            'select_applicable_settings': self.select_applicable_settings,
        }

    def _matches(self, condition, props):
        """Check if a single condition matches the properties"""
        if not isinstance(condition, dict):
            return False
        return any(props.get(prop) == value for prop, value in condition.items())

    def _evaluate_or(self, conditions, props):
        """Evaluate OR conditions - returns True if any condition matches"""
        return any(self._matches(cond, props) for cond in conditions)

    def _evaluate_and(self, conditions, props):
        """Evaluate AND conditions - returns True if all conditions match"""
        if not conditions:
            return False
        return all(self._matches(cond, props) for cond in conditions)

    def _evaluate_true(self, conditions, props):
        """Always returns True"""
        return True

    def select_applicable_settings(self, settings_map, selection_properties):
        """
        Filter performance settings based on conditional logic
        
        Original Groovy method: getApplicableSettings(settingsMap, selectionProperties)
        
        Args:
            settings_map: Dictionary of setting entries with conditions
            selection_properties: Dictionary of VPD properties (mtm, model, etc.)
            
        Returns:
            Dictionary of applicable settings to apply
            
        Example settings_map structure:
        {
            "setting_group_1": {
                "conditionOperator": true,  # or "or" or "and"
                "conditions": [
                    {"mtm": "7X02"},
                    {"model": "SR650"}
                ],
                "settings": {
                    "ProcessorHyperThreading.ProcessorHyperThreading": "Enable",
                    "ProcessorC1EnhancedMode.ProcessorC1EnhancedMode": "Disable"
                }
            }
        }
        """
        if not isinstance(settings_map, dict):
            return {}
            
        if not isinstance(selection_properties, dict):
            selection_properties = {}
        
        operator_handlers = {
            'true': self._evaluate_true,
            'or': self._evaluate_or,
            'and': self._evaluate_and
        }
        
        return_map = {}
        
        for key, setting_entry in settings_map.items():
            if not isinstance(setting_entry, dict):
                continue
                
            condition_operator = setting_entry.get('conditionOperator')
            conditions = setting_entry.get('conditions', [])
            settings = setting_entry.get('settings', {})
            
            operator = str(condition_operator).lower() if condition_operator is not True else 'true'
            
            handler = operator_handlers.get(operator)
            if handler and handler(conditions, selection_properties):
                return_map.update(settings)
        
        return return_map
