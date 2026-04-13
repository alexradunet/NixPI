export type PromptRequest = {
  prompt: string;
  sessionPath?: string | null;
};

export type PromptResponse = {
  text: string;
  sessionPath: string;
};
