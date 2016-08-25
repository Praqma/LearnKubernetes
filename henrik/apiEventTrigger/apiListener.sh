kubectl get events --watch-only=true | awk '/Started container/ { system("echo Started container") }
                                            /Killing container/ { system("echo Killed container") }'
