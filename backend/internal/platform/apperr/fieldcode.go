package apperr

// FieldCode is a 422 VALIDATION_ERROR for one invalid field with a stable
// detail code (details[0].code) and the values it refers to
// (details[0].params), so clients can localize the message.
func FieldCode(field, code, msg string, params map[string]string) *Error {
	return Validation("The request could not be processed.", Detail{Field: field, Message: msg, Code: code, Params: params})
}
