"use client";
import { useTranslation } from "react-i18next";
import { PiPaperclipFill } from "react-icons/pi";

import Button from "@/lib/components/ui/Button";

import { ChatBar } from "./components/ChatBar/ChatBar";
import { ConfigModal } from "./components/ConfigModal";
import { useChatInput } from "./hooks/useChatInput";

type ChatInputProps = {
  shouldDisplayUploadCard: boolean;
  setShouldDisplayUploadCard: (shouldDisplayUploadCard: boolean) => void;
};

export const ChatInput = ({
  shouldDisplayUploadCard,
  setShouldDisplayUploadCard,
}: ChatInputProps): JSX.Element => {
  const { setMessage, submitQuestion, generatingAnswer, message } =
    useChatInput();
  const { t } = useTranslation(["chat"]);

  return (
    <form
      data-testid="chat-input-form"
      onSubmit={(e) => {
        e.preventDefault();
        submitQuestion();
      }}
      className="sticky bottom-0 bg-white dark:bg-black w-full flex items-center gap-2 z-20 p-2"
    >
      {!shouldDisplayUploadCard && (
        <Button
          className="p-0"
          variant={"tertiary"}
          data-testid="upload-button"
          type="button"
          onClick={() => setShouldDisplayUploadCard(true)}
          tooltip={t("add_content_card_button_tooltip")}
        >
          <PiPaperclipFill className="text-3xl" />
        </Button>
      )}

      <div className="flex flex-1 flex-col items-center">
        <ChatBar
          message={message}
          setMessage={setMessage}
          onSubmit={submitQuestion}
        />
      </div>

      <div className="flex flex-row items-end">
        <Button
          className="px-3 py-2 sm:px-4 sm:py-2"
          type="submit"
          isLoading={generatingAnswer}
          data-testid="submit-button"
        >
          {generatingAnswer
            ? t("thinking", { ns: "chat" })
            : t("chat", { ns: "chat" })}
        </Button>
        <div className="hidden md:flex items-center">
          <ConfigModal />
        </div>
      </div>
    </form>
  );
};
