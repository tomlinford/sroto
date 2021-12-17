// Code generated by "enumer -type=OptionType -json -transform=snake"; DO NOT EDIT.

//
package sroto_ir

import (
	"encoding/json"
	"fmt"
)

const _OptionTypeName = "file_optionmessage_optionfield_optiononeof_optionenum_optionenum_value_optionservice_optionmethod_option"

var _OptionTypeIndex = [...]uint8{0, 11, 25, 37, 49, 60, 77, 91, 104}

func (i OptionType) String() string {
	i -= 1
	if i < 0 || i >= OptionType(len(_OptionTypeIndex)-1) {
		return fmt.Sprintf("OptionType(%d)", i+1)
	}
	return _OptionTypeName[_OptionTypeIndex[i]:_OptionTypeIndex[i+1]]
}

var _OptionTypeValues = []OptionType{1, 2, 3, 4, 5, 6, 7, 8}

var _OptionTypeNameToValueMap = map[string]OptionType{
	_OptionTypeName[0:11]:   1,
	_OptionTypeName[11:25]:  2,
	_OptionTypeName[25:37]:  3,
	_OptionTypeName[37:49]:  4,
	_OptionTypeName[49:60]:  5,
	_OptionTypeName[60:77]:  6,
	_OptionTypeName[77:91]:  7,
	_OptionTypeName[91:104]: 8,
}

// OptionTypeString retrieves an enum value from the enum constants string name.
// Throws an error if the param is not part of the enum.
func OptionTypeString(s string) (OptionType, error) {
	if val, ok := _OptionTypeNameToValueMap[s]; ok {
		return val, nil
	}
	return 0, fmt.Errorf("%s does not belong to OptionType values", s)
}

// OptionTypeValues returns all values of the enum
func OptionTypeValues() []OptionType {
	return _OptionTypeValues
}

// IsAOptionType returns "true" if the value is listed in the enum definition. "false" otherwise
func (i OptionType) IsAOptionType() bool {
	for _, v := range _OptionTypeValues {
		if i == v {
			return true
		}
	}
	return false
}

// MarshalJSON implements the json.Marshaler interface for OptionType
func (i OptionType) MarshalJSON() ([]byte, error) {
	return json.Marshal(i.String())
}

// UnmarshalJSON implements the json.Unmarshaler interface for OptionType
func (i *OptionType) UnmarshalJSON(data []byte) error {
	var s string
	if err := json.Unmarshal(data, &s); err != nil {
		return fmt.Errorf("OptionType should be a string, got %s", data)
	}

	var err error
	*i, err = OptionTypeString(s)
	return err
}
