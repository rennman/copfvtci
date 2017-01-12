/*
Copyright IBM Corp. 2016 All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

                 http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package lib

import (
	"io/ioutil"
	"testing"
)

func getIdentity() *Identity {
	key, _ := ioutil.ReadFile("../tesdata/ec-key.pem")
	cert, _ := ioutil.ReadFile("../tesdata/ec.pem")
	id := newIdentity(nil, "test", key, cert)
	return id
}

func TestIdentity(t *testing.T) {
	id := getIdentity()
	testGetName(id, t)
	testGetPublicSigner(id, t)
	testGetAttributeNames(id, t)
	testDelete(id, t)
}

func testGetName(id *Identity, t *testing.T) {
	name := id.GetName()
	if name != "test" {
		t.Error("Incorrect name retrieved")
	}
}

func testGetPublicSigner(id *Identity, t *testing.T) {
	publicSigner := id.GetPublicSigner()
	if publicSigner == nil {
		t.Error("No public signer returned")
	}
}

// Place holder test, method has not yet been implemented
func testGetAttributeNames(id *Identity, t *testing.T) {
	id.GetAttributeNames()
}

// Place holder test, method has not yet been implemented
func testDelete(id *Identity, t *testing.T) {
	id.Delete()
}
